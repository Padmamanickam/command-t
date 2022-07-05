/**
 * SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell. All rights reserved.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef SCANNER_H
#define SCANNER_H

#include <stddef.h> /* for size_t */

#include "str.h"

typedef struct {
    // TODO: const
    str_t **candidates;

    /**
     * Number of candidates currently stored in the scanner.
     */
    size_t count;

    /**
     * Available capacity in the scanner.
     */
    size_t capacity;

    /**
     * Counter that increments any time the candidates change.
     */
    unsigned clock; // TODO: figure out whether I need this
} scanner_t;

/**
 * Create a new `scanner_t` struct initialized with `capacity`. If `capacity` is
 * 0, the default capacity is used.
 */
scanner_t *scanner_new(size_t capacity);

/**
 * Frees a previously created `scanner_t` structure.
 */
void scanner_free(scanner_t *scanner);

#endif
