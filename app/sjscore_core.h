#ifndef SJSCORE_CORE_H
#define SJSCORE_CORE_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct SJEngine SJEngine;

typedef struct SJLayoutMetrics {
    double canvasWidth;
    double canvasHeight;
    double marginTop;
    double marginLeft;
    double rowGap;
    double staveHeight;
    int rows;
    int measuresPerRow;
    int slotsPerMeasure;
    int slotsPerRow;
    int slotsPerPage;
    double slotWidth;
    double measureWidth;
} SJLayoutMetrics;

enum {
    SJ_SUFFIX_NORMAL = 0,
    SJ_SUFFIX_DIM_OR_HALFDIM = 1,
    SJ_SUFFIX_SUS = 2,
    SJ_SUFFIX_ADD_OR_AUG = 3
};

typedef struct SJChordLayoutC {
    int hasChord;
    int isSyncopated;
    int isSelected;
    int isActiveCursor;
    char *root;
    char *suffix;
    int suffixStyleHint;
    char *bass;
    char *unparsed;
    int tensionCount;
    char *tensions[8];
} SJChordLayoutC;

void sj_core_init(void);
void sj_free_string(char *s);
void sj_free_chord_layout(SJChordLayoutC *layout);

SJEngine *sj_engine_new(void);
void sj_engine_free(SJEngine *h);

void sj_engine_get_layout(SJEngine *h, SJLayoutMetrics *outMetrics);
void sj_engine_slot_coords(SJEngine *h, int localIndex, double *outX, double *outY);
double sj_engine_row_y(SJEngine *h, int rowIndex);

char *sj_engine_get_title(SJEngine *h);
void sj_engine_set_title(SJEngine *h, const char *title);

char *sj_engine_get_status(SJEngine *h);
void sj_engine_set_status(SJEngine *h, const char *msg);

int sj_engine_get_view_page(SJEngine *h);
int sj_engine_get_total_pages(SJEngine *h);
int sj_engine_get_max_pages(void);
int sj_engine_get_effective_pdf_pages(SJEngine *h);
int sj_engine_get_slot_count(SJEngine *h);

double sj_engine_get_zoom(SJEngine *h);
void sj_engine_zoom_in(SJEngine *h);
void sj_engine_zoom_out(SJEngine *h);
void sj_engine_reset_zoom(SJEngine *h);

int sj_engine_get_transpose(SJEngine *h);
void sj_engine_set_transpose(SJEngine *h, int value);
int sj_engine_is_read_only(SJEngine *h);
int sj_engine_is_editing_title(SJEngine *h);
void sj_engine_set_editing_title(SJEngine *h, int editing);

void sj_engine_prev_page(SJEngine *h);
void sj_engine_next_page(SJEngine *h);

int sj_engine_mouse_down(SJEngine *h, double x, double y);
void sj_engine_mouse_drag(SJEngine *h, int anchor, double x, double y);

void sj_engine_move_cursor(SJEngine *h, int delta, int extendSel);
void sj_engine_move_measure(SJEngine *h, int direction, int extendSel);
void sj_engine_move_content(SJEngine *h, int delta);
void sj_engine_delete_char(SJEngine *h);
void sj_engine_delete_selection(SJEngine *h);
void sj_engine_toggle_syncopation(SJEngine *h);
void sj_engine_copy_selection(SJEngine *h);
void sj_engine_paste_clipboard(SJEngine *h);
void sj_engine_append_char(SJEngine *h, char ch);

int sj_engine_load_json(SJEngine *h, const char *jsonStr, const char *fileName);
char *sj_engine_save_json(SJEngine *h, const char *fileName);

void sj_engine_get_slot_render(
    SJEngine *h,
    int globalIndex,
    int transposeOverride,
    SJChordLayoutC *outLayout
);

#ifdef __cplusplus
}
#endif

#endif /* SJSCORE_CORE_H */
