/* sane-airscan backend test
 *
 * Copyright (C) 2019 and up by Alexander Pevzner (pzz@apevzner.com)
 * See LICENSE for license terms and conditions
 */

#include <sane/sane.h>

#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "airscan.h"

SANE_Handle handle;

void
sigint_handler (int unused)
{
    (void) unused;
    if (handle != NULL) {
        sane_cancel (handle);
    }
}

void
check (SANE_Status status, const char *operation)
{
    if (status != SANE_STATUS_GOOD) {
        printf("%s: %s\n", operation, sane_strstatus(status));
        if (handle != NULL) {
            sane_close(handle);
        }
        exit(1);
    }
}

#define TRY(func, args...)              \
    do{                                 \
        SANE_Status s = func(args);     \
        check(s, #func);                \
    } while(0)

int
main (int argc, char** argv)
{
    SANE_Parameters params;

    struct sigaction act = {
        .sa_handler = sigint_handler,
    };

    sigaction(SIGINT, &act, NULL);

    TRY(sane_init, NULL, NULL);
    TRY(sane_open, "", &handle);
    //TRY(sane_control_option, handle, OPT_SCAN_SOURCE, SANE_ACTION_SET_VALUE, OPTVAL_SOURCE_ADF_SIMPLEX, NULL);
    TRY(sane_get_parameters, handle, &params);
    printf("image size: %dx%d\n", params.pixels_per_line, params.lines);

    TRY(sane_start,handle);

    SANE_Status s;
    SANE_Byte   buf[65536];
    int         len, count = 0;
    FILE*       f = NULL;

    if (argc > 1) {
        f = fopen(argv[1], "w+b");
        if (!f) {
            fprintf(stderr, "error: could not open file '%s'\n", argv[1]);
        } else {
            fprintf(f, "P6\n%d %d %d\n", params.pixels_per_line, params.lines, 255);
        }
    }

    for (;;) {
        s = sane_read(handle, buf, sizeof(buf), &len);
        if (s != SANE_STATUS_GOOD) {
            break;
        }
        if (f) {
            if ((size_t)len != fwrite(buf, 1, (size_t)len, f)) {
                fprintf(stderr, "error: could not write to file, output file removed\n");
                fclose(f);
                f = NULL;
                unlink(argv[1]);
            }
        }

        count += len;
    }
    if (count != 0) {
        printf("%d bytes of data received\n", count);
    }
    if (f) {
        fclose(f);
        f = NULL;
    }

    //getchar();

    sane_close(handle);
    sane_exit();

    return 0;
}

/* vim:ts=8:sw=4:et
 */
