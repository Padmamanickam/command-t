/**
 * SPDX-FileCopyrightText: Copyright 2014-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <assert.h> /* for assert() */
#include <fcntl.h> /* for F_GETFL, F_SETFL, O_NONBLOCK, fcntl() */
#include <limits.h> /* for SSIZE_MAX */
#include <stdint.h> /* for uint8_t */
#include <stdlib.h> /* for abort(), free() */
#include <string.h> /* for memset(), strncpy() */
#include <sys/errno.h> /* for errno */
#include <sys/socket.h> /* for AF_LOCAL, recv(), MSG_PEEK */
#include <sys/un.h> /* for sockaddr_un */
#include <unistd.h> /* for close() */

#include "str.h"
#include "watchman.h"
#include "xmalloc.h" /* for xmalloc() */

// TODO: mark most of these functions as static (internal only)
// TODO: use setjmp()/longjmp() to implement exception-like semantics when processing responses (we don't really want to be calling abort() for everything unexpected).

typedef struct {
    uint8_t *payload;
    size_t capacity;
    size_t length;
} watchman_request_t;

// TODO: Either use uint8_t for both requests and responses, or char for both.
typedef struct {
    size_t capacity;
    char *payload;
    char *ptr;
    char *end;
} watchman_response_t;

// Forward declarations of static functions.

static void watchman_append(watchman_request_t *w, const char *data, size_t length);
static watchman_request_t *watchman_init();
static double watchman_read_double(char **ptr, char *end);
static int64_t watchman_read_int(watchman_response_t *r);
static str_t *watchman_read_string(watchman_response_t *r);
static void watchman_response_free(watchman_response_t *r);
static watchman_response_t *watchman_send_query(watchman_request_t *w, int socket);
static void watchman_write_array(watchman_request_t *w, unsigned length);
static void watchman_write_int(watchman_request_t *w, int64_t num);
static void watchman_write_object(watchman_request_t *w, unsigned size);
static void watchman_write_string(watchman_request_t *w, const char *string, size_t length);

#define WATCHMAN_DEFAULT_STORAGE    4096

#define WATCHMAN_BINARY_MARKER      "\x00\x01"
#define WATCHMAN_ARRAY_MARKER       0x00
#define WATCHMAN_OBJECT_MARKER      0x01
#define WATCHMAN_STRING_MARKER      0x02
#define WATCHMAN_INT8_MARKER        0x03
#define WATCHMAN_INT16_MARKER       0x04
#define WATCHMAN_INT32_MARKER       0x05
#define WATCHMAN_INT64_MARKER       0x06
#define WATCHMAN_FLOAT_MARKER       0x07
#define WATCHMAN_TRUE               0x08
#define WATCHMAN_FALSE              0x09
#define WATCHMAN_NIL                0x0a
#define WATCHMAN_TEMPLATE_MARKER    0x0b
#define WATCHMAN_SKIP_MARKER        0x0c

#define WATCHMAN_HEADER \
        WATCHMAN_BINARY_MARKER \
        "\x06" \
        "\x00\x00\x00\x00\x00\x00\x00\x00"

// How far we have to look to figure out the size of the PDU header.
#define WATCHMAN_SNIFF_BUFFER_SIZE (sizeof(WATCHMAN_BINARY_MARKER) - 1 + sizeof(int8_t))

// How far we have to peek, at most, to figure out the size of the PDU itself.
#define WATCHMAN_PEEK_BUFFER_SIZE \
    (sizeof(WATCHMAN_BINARY_MARKER) - 1 + sizeof(typeof(WATCHMAN_INT64_MARKER)) + sizeof(int64_t))

static const char watchman_array_marker  = WATCHMAN_ARRAY_MARKER;
static const char watchman_object_marker = WATCHMAN_OBJECT_MARKER;
static const char watchman_string_marker = WATCHMAN_STRING_MARKER;
static const char watchman_true          = WATCHMAN_TRUE;
static const char watchman_false         = WATCHMAN_FALSE;
static const char watchman_nil           = WATCHMAN_NIL;

/**
 * Appends `length` bytes, starting at `data`, to the watchman_request_t struct `w`
 *
 * Will attempt to reallocate the underlying storage if it is not sufficient.
 */
static void watchman_append(watchman_request_t *w, const char *data, size_t length) {
    if (w->length + length > w->capacity) {
        w->capacity += w->length + WATCHMAN_DEFAULT_STORAGE;
        xrealloc(w->payload, sizeof(uint8_t) * w->capacity);
    }
    memcpy(w->payload + w->length, data, length);
    w->length += length;
}

/**
 * Allocate a new watchman_request_t struct
 *
 * The struct has a small amount of extra capacity preallocated, and a blank
 * header that can be filled in later to describe the PDU.
 */
static watchman_request_t *watchman_init() {
    watchman_request_t *w = xmalloc(sizeof(watchman_request_t));
    w->capacity = WATCHMAN_DEFAULT_STORAGE;
    w->length = 0;
    w->payload = xcalloc(WATCHMAN_DEFAULT_STORAGE, sizeof(uint8_t));
    watchman_append(w, WATCHMAN_HEADER, sizeof(WATCHMAN_HEADER) - 1);
    return w;
}

/**
 * Free a watchman_request_t struct `w` that was previously allocated with
 * `watchman_init`
 */
void watchman_free(watchman_request_t *w) {
    free(w->payload);
    free(w);
}

/**
 * Encodes and appends the integer `num` to `w`
 */
static void watchman_write_int(watchman_request_t *w, int64_t num) {
    char encoded[1 + sizeof(int64_t)];
    if (num == (int8_t)num) {
        encoded[0] = WATCHMAN_INT8_MARKER;
        encoded[1] = (int8_t)num;
        watchman_append(w, encoded, 1 + sizeof(int8_t));
    } else if (num == (int16_t)num) {
        encoded[0] = WATCHMAN_INT16_MARKER;
        *(int16_t *)(encoded + 1) = (int16_t)num;
        watchman_append(w, encoded, 1 + sizeof(int16_t));
    } else if (num == (int32_t)num) {
        encoded[0] = WATCHMAN_INT32_MARKER;
        *(int32_t *)(encoded + 1) = (int32_t)num;
        watchman_append(w, encoded, 1 + sizeof(int32_t));
    } else {
        encoded[0] = WATCHMAN_INT64_MARKER;
        *(int64_t *)(encoded + 1) = (int64_t)num;
        watchman_append(w, encoded, 1 + sizeof(int64_t));
    }
}

/**
 * Encodes and appends the string `string` to `w`
 */
static void watchman_write_string(watchman_request_t *w, const char *string, size_t length) {
    watchman_append(w, &watchman_string_marker, sizeof(watchman_string_marker));
    watchman_write_int(w, length);
    watchman_append(w, string, length);
}

/**
 * Prepares to encode an object of `size` key/value pairs.
 *
 * After calling this, the caller should call, for each key/value pair, first
 * `watchman_write_string()` (for the key), then some other `watchman_write`
 * function for the value.
 */
static void watchman_write_object(watchman_request_t *w, unsigned size) {
    watchman_append(w, &watchman_object_marker, sizeof(watchman_object_marker));
    watchman_write_int(w, size);
}

static int64_t watchman_read_int(watchman_response_t *r) {
    char *val_ptr = r->ptr + sizeof(int8_t);
    int64_t val = 0;

    if (val_ptr >= r->end) {
        abort(); // Insufficient int storage.
    }

    switch (r->ptr[0]) {
        case WATCHMAN_INT8_MARKER:
            if (val_ptr + sizeof(int8_t) > r->end) {
                abort(); // Overrun extracting int8_t.
            }
            val = *(int8_t *)val_ptr;
            r->ptr = val_ptr + sizeof(int8_t);
            break;
        case WATCHMAN_INT16_MARKER:
            if (val_ptr + sizeof(int16_t) > r->end) {
                abort(); // Overrun extracting int16_t.
            }
            val = *(int16_t *)val_ptr;
            r->ptr = val_ptr + sizeof(int16_t);
            break;
        case WATCHMAN_INT32_MARKER:
            if (val_ptr + sizeof(int32_t) > r->end) {
                abort(); // Overrun extracting int32_t.
            }
            val = *(int32_t *)val_ptr;
            r->ptr = val_ptr + sizeof(int32_t);
            break;
        case WATCHMAN_INT64_MARKER:
            if (val_ptr + sizeof(int64_t) > r->end) {
                abort(); // Overrun extracting int64_t.
            }
            val = *(int64_t *)val_ptr;
            r->ptr = val_ptr + sizeof(int64_t);
            break;
        default:
            abort(); // Bad integer marker.
            break;
    }

    return val;
}

/**
 * Reads and returns a string encoded in the Watchman binary protocol format,
 * starting at `ptr` and finishing at or before `end`
 */
static str_t *watchman_read_string(watchman_response_t *r) {
    int64_t length;
    if (r->ptr >= r->end) {
        abort(); // Unexpected end of input.
    }

    if (r->ptr[0] != WATCHMAN_STRING_MARKER) {
        abort(); // Not a number.
    }

    r->ptr += sizeof(int8_t);
    if (r->ptr >= r->end) {
        abort(); // Invalid string header.
    }

    length = watchman_read_int(r);
    if (length == 0) { // Special case for zero-length strings.
        return str_new_copy("", 0);
    } else if (r->ptr + length > r->end) {
        abort(); // Insufficient string storage.
    }

    str_t *string = str_new_copy(r->ptr, length);
    r->ptr += length;
    return string;
}

/**
 * Reads and returns a double encoded in the Watchman binary protocol format,
 * starting at `ptr` and finishing at or before `end`
 */
static double watchman_read_double(char **ptr, char *end) {
    double val;
    *ptr += sizeof(int8_t); // Caller has already verified the marker.
    if (*ptr + sizeof(double) > end) {
        abort(); // Insufficient double storage.
    }
    val = *(double *)*ptr;
    *ptr += sizeof(double);
    return val;
}

#if 0

/**
 * Reads and returns an array encoded in the Watchman binary protocol format,
 * starting at `ptr` and finishing at or before `end`
 */
VALUE watchman_read_array(char **ptr, char *end) {
    int64_t count, i;
    VALUE array;

    if (*ptr >= end) {
        abort(); // Unexpected end of input.
    }

    // Verify and consume marker.
    if (*ptr[0] != WATCHMAN_ARRAY_MARKER) {
        abort(); // Not an array.
    }
    *ptr += sizeof(int8_t);

    // Expect a count.
    if (*ptr + sizeof(int8_t) * 2 > end) {
        abort(); // Incomplete array header.
    }

    int64_t count = watchman_read_int(ptr, end);

    array = rb_ary_new2(count);

    for (i = 0; i < count; i++) {
        rb_ary_push(array, watchman_load(ptr, end));
    }

    return array;
}

/**
 * Reads and returns a hash encoded in the Watchman binary protocol format,
 * starting at `ptr` and finishing at or before `end`
 */
VALUE watchman_read_hash(char **ptr, char *end) {
    int64_t count, i;
    VALUE hash, key, value;

    *ptr += sizeof(int8_t); // caller has already verified the marker

    // expect a count
    if (*ptr + sizeof(int8_t) * 2 > end) {
        rb_raise(rb_eArgError, "incomplete hash header");
    }
    count = watchman_read_int(ptr, end);

    hash = rb_hash_new();

    for (i = 0; i < count; i++) {
        key = watchman_read_string(ptr, end);
        value = watchman_load(ptr, end);
        rb_hash_aset(hash, key, value);
    }

    return hash;
}

/**
 * Reads and returns an object encoded in the Watchman binary protocol format,
 * starting at `ptr` and finishing at or before `end`
 */
VALUE watchman_load(char **ptr, char *end) {
    if (*ptr >= end) {
        abort(); // Unexpected end of input.
    }

    switch (*ptr[0]) {
        case WATCHMAN_ARRAY_MARKER:
            return watchman_read_array(ptr, end);
        case WATCHMAN_OBJECT_MARKER:
            return watchman_read_hash(ptr, end);
        case WATCHMAN_STRING_MARKER:
            return watchman_read_string(ptr, end);
        case WATCHMAN_INT8_MARKER:
        case WATCHMAN_INT16_MARKER:
        case WATCHMAN_INT32_MARKER:
        case WATCHMAN_INT64_MARKER:
            // TODO: skip over numbers (never expect to see any of these...)
            return LL2NUM(watchman_read_int(ptr, end));
        case WATCHMAN_FLOAT_MARKER:
            // TODO: skip over numbers (never expect to see any of these...)
            return rb_float_new(watchman_read_double(ptr, end));
        case WATCHMAN_TRUE:
            // TODO: skip over bools (never expect to see any of these...)
            *ptr += 1;
            return Qtrue;
        case WATCHMAN_FALSE:
            // TODO: skip over bools (never expect to see any of these...)
            *ptr += 1;
            return Qfalse;
        case WATCHMAN_NIL:
            // TODO: skip over nils/nulls (never expect to see any of these...)
            *ptr += 1;
            return Qnil;
        case WATCHMAN_TEMPLATE_MARKER:
        default:
            abort(); // Unsupported type.
    }

    return Qnil; // keep the compiler happy
}

/**
 * CommandT::Watchman::Utils.load(serialized)
 *
 * Converts the binary object, `serialized`, from the Watchman binary protocol
 * format into a normal Ruby object.
 */
VALUE CommandTWatchmanUtils_load(VALUE self, VALUE serialized) {
    char *ptr, *end;
    long length;
    uint64_t payload_size;
    VALUE loaded;
    serialized = StringValue(serialized);
    length = RSTRING_LEN(serialized);
    ptr = RSTRING_PTR(serialized);
    end = ptr + length;

    // expect at least the binary marker and a int8_t length counter
    if ((size_t)length < sizeof(WATCHMAN_BINARY_MARKER) - 1 + sizeof(int8_t) * 2) {
        rb_raise(rb_eArgError, "undersized header");
    }

    if (memcmp(ptr, WATCHMAN_BINARY_MARKER, sizeof(WATCHMAN_BINARY_MARKER) - 1)) {
        rb_raise(rb_eArgError, "missing binary marker");
    }

    // get size marker
    ptr += sizeof(WATCHMAN_BINARY_MARKER) - 1;
    payload_size = watchman_read_int(&ptr, end);
    if (!payload_size) {
        rb_raise(rb_eArgError, "empty payload");
    }

    // sanity check length
    if (ptr + payload_size != end) {
        rb_raise(
            rb_eArgError,
            "payload size mismatch (%lu)",
            (unsigned long)(end - (ptr + payload_size))
        );
    }

    loaded = watchman_load(&ptr, end);

    // one more sanity check
    if (ptr != end) {
        rb_raise(
            rb_eArgError,
            "payload termination mismatch (%lu)",
            (unsigned long)(end - ptr)
        );
    }

    return loaded;
}

#endif

int commandt_watchman_connect(const char *socket_path) {
    int fd = socket(PF_LOCAL, SOCK_STREAM, 0);
    if (fd == -1) {
        return -1;
    }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(struct sockaddr_un) - 1);
    addr.sun_family = AF_LOCAL;

    // On macOS, `sun_path` is 104 bytes long... so good thing the socket path
    // is only: "/opt/homebrew/var/run/watchman/$USER-state/sock"...
    strncpy(addr.sun_path, socket_path, sizeof(addr.sun_path) - 1);

    if (connect(fd, (struct sockaddr *)&addr, sizeof(struct sockaddr_un)) == -1) {
        return -1;
    }

    // Do blocking I/O to make logic simpler.
    int flags = fcntl(fd, F_GETFL);
    if (flags == -1) {
        return -1;
    }
    if (fcntl(fd, F_SETFL, flags & ~O_NONBLOCK) == -1) {
        return -1;
    }

    return fd;
}

int commandt_watchman_disconnect(int socket) {
    if (close(socket) == 0) {
        return 0;
    } else {
        return errno;
    }
}

watchman_query_result_t *commandt_watchman_query(
    const char *root,
    const char *relative_root,
    int socket
) {
    // Prepare the message.
    //
    //     [
    //       "query",
    //       "/path/to/root", {
    //         "expression": ["type", "f"],
    //         "fields": ["name"],
    //         "relative_root": "relative/path"
    //       }
    //     ]
    //
    watchman_request_t *w = watchman_init();
    watchman_write_array(w, 3);
    watchman_write_string(w, "query", sizeof("query"));
    watchman_write_string(w, root, strlen(root));
    watchman_write_object(w, relative_root ? 3 : 2);
    watchman_write_string(w, "expression", sizeof("expression"));
    watchman_write_array(w, 2);
    watchman_write_string(w, "type", sizeof("type"));
    watchman_write_string(w, "f", sizeof("f"));
    watchman_write_string(w, "fields", sizeof("fields"));
    watchman_write_array(w, 1);
    watchman_write_string(w, "name", sizeof("name"));
    if (relative_root) {
        watchman_write_string(w, "relative_root", sizeof("relative_root"));
        watchman_write_string(w, relative_root, strlen(relative_root));
    }

    watchman_response_t *response = watchman_send_query(w, socket);

    // 2. extract "files"
    // 3. return NULL if "error"

    watchman_response_free(response);

    watchman_query_result_t *result = xmalloc(sizeof(watchman_query_result_t));

    return result;
}

void commandt_watchman_query_result_free(watchman_query_result_t *result) {
    // TODO: free more stuff...
    free(result);
}

static void watchman_write_array(watchman_request_t *w, unsigned length) {
    watchman_append(w, &watchman_array_marker, sizeof(watchman_array_marker));
    watchman_write_int(w, length);
}

/**
 * Returns count of key/value pairs in the object.
 */
static int watchman_read_object(watchman_response_t *r) {
    int count = 0;
    if (r->ptr >= r->end) {
        abort(); // Unexpected end of input.
    }
    if (r->ptr[0] == WATCHMAN_OBJECT_MARKER) {
        r->ptr++;
        if (r->ptr + 2 > r->end) {
            abort(); // Incomplete hash header.
        }
        count = watchman_read_int(r);
    } else {
        abort();
    }
    return count;
}

watchman_watch_project_result_t *commandt_watchman_watch_project(
    const char *root,
    int socket
) {
    // Prepare the message.
    //
    //     ["watch-project", "/path/to/root"]
    //
    watchman_request_t *w = watchman_init();
    watchman_write_array(w, 2);
    watchman_write_string(w, "watch-project", sizeof("watch-project"));
    watchman_write_string(w, root, strlen(root));

    watchman_response_t *response = watchman_send_query(w, socket);
    // TODO: do something with response
    // ruby did this:
    // loaded = watchman_load(&payload, payload + payload_size);
    // we'll do this:
    // ...
    // 2. extract "watch"
    // 3. extract "relative_path", if present
    // 4. return NULL if "error" is present

    int count = watchman_read_object(response);

    // TODO: read `count` key/value pairs, looking for the keys we care
    // about...

    watchman_response_free(response);

    watchman_watch_project_result_t *result =
        xmalloc(sizeof(watchman_watch_project_result_t));

    return result;
}

static void watchman_response_free(watchman_response_t *r) {
    free(r->payload);
    free(r);
}

static watchman_response_t *watchman_send_query(watchman_request_t *w, int socket) {
    watchman_response_t *r = xmalloc(sizeof(watchman_response_t));
    r->capacity = WATCHMAN_DEFAULT_STORAGE;
    r->payload = xmalloc(WATCHMAN_DEFAULT_STORAGE);
    r->ptr = r->payload;
    r->end = r->payload;

    // Send the message.
    assert(w->length < SSIZE_MAX);
    ssize_t length = w->length;
    ssize_t sent = send(socket, w->payload, w->length, 0);
    if (sent == -1 || sent != length) {
        return NULL; // TODO: don't leak response for these early returns
    }

    // Sniff to see how large the header is.
    ssize_t received = recv(socket, r->payload, WATCHMAN_SNIFF_BUFFER_SIZE, MSG_PEEK | MSG_WAITALL);
    if (received == -1 || received != WATCHMAN_SNIFF_BUFFER_SIZE) {
        return NULL;
    }

    // Peek at size of PDU.
    int8_t sizes_idx = r->ptr[sizeof(WATCHMAN_BINARY_MARKER) - 1];
    if (sizes_idx < WATCHMAN_INT8_MARKER || sizes_idx > WATCHMAN_INT64_MARKER) {
        return NULL;
    }
    int8_t sizes[] = {0, 0, 0, 1, 2, 4, 8};
    ssize_t peek_size = sizeof(WATCHMAN_BINARY_MARKER) - 1 + sizeof(int8_t) +
        sizes[sizes_idx];

    received = recv(socket, r->payload, peek_size, MSG_PEEK);
    if (received == -1 || received != peek_size) {
        return NULL;
    }
    r->ptr = r->ptr + sizeof(WATCHMAN_BINARY_MARKER) - sizeof(int8_t);
    r->end = r->ptr + peek_size;
    int64_t payload_size = peek_size + watchman_read_int(r);

    // Actually read the PDU.
    assert(payload_size > 0);
    if ((size_t)payload_size > r->capacity) {
        r->payload = xrealloc(r->payload, payload_size);
    }

    received = recv(socket, r->payload, payload_size, MSG_WAITALL);
    if (received == -1 || received != payload_size) {
        return NULL;
    }

    r->ptr = r->payload + peek_size;
    r->end = r->payload + peek_size + payload_size;
    r->capacity = payload_size;

    return r;
}

void commandt_watchman_watch_project_result_free(
    watchman_watch_project_result_t *result
) {
    free((void *)result->watch);
    free((void *)result->relative_path);
    free(result);
}
