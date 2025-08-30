#ifndef TesseractWrapper_h
#define TesseractWrapper_h

#ifdef __cplusplus
extern "C" {
#endif

// C interface for Swift with full user control and character filtering support
typedef void* TesseractHandle;

typedef struct {
    char* text;
    float confidence;
} OCRResult;

// Core functions
TesseractHandle tesseract_create(const char* datapath, const char* language);
void tesseract_destroy(TesseractHandle handle);
int tesseract_set_image_data(TesseractHandle handle,
                            unsigned char* data,
                            int width,
                            int height,
                            int bytes_per_pixel,
                            int bytes_per_line);
OCRResult tesseract_get_text_with_confidence(TesseractHandle handle);
void tesseract_free_ocr_result(OCRResult* result);

// Page Segmentation Mode (PSM) - User configurable
// PSM modes: 0=OSD only, 1=Auto+OSD, 2=Auto, 3=Auto (default), 4=Single column,
// 5=Single block, 6=Single line, 7=Single word, 8=Single char, 9=Circle word,
// 10=Single char (better), 11=Sparse text, 12=Sparse+OSD, 13=Raw line
int tesseract_set_page_seg_mode(TesseractHandle handle, int psm);
int tesseract_get_page_seg_mode(TesseractHandle handle);

// OCR Engine Mode (OEM) - User configurable
// WARNING: Character filtering ONLY works with Legacy engine (OEM 0)
// OEM modes: 0=Legacy only (required for char filtering), 1=LSTM only (ignores char filtering),
// 2=Legacy+LSTM, 3=Default based on available
int tesseract_set_oem(TesseractHandle handle, int oem);
int tesseract_get_oem(TesseractHandle handle);

// Generic variable setting - Full user control over any Tesseract parameter
// WARNING: Character filtering variables only work with Legacy OCR engine (OEM 0)
// Common variables: tessedit_char_whitelist, tessedit_char_blacklist,
// classify_bln_numeric_mode, tessedit_write_images, etc.
int tesseract_set_variable(TesseractHandle handle, const char* name, const char* value);
const char* tesseract_get_variable(TesseractHandle handle, const char* name);

// Character filtering convenience functions
// WARNING: These ONLY work with Legacy OCR engine (OEM 0)
// LSTM engine (OEM 1) completely ignores character filtering
int tesseract_set_whitelist(TesseractHandle handle, const char* whitelist);
int tesseract_set_blacklist(TesseractHandle handle, const char* blacklist);

// Setup helper for character filtering
// WARNING: This switches to Legacy OCR engine which may be less accurate
int tesseract_setup_for_character_filtering(TesseractHandle handle);

// Version and configuration info
const char* tesseract_get_version();
const char* tesseract_get_datapath(TesseractHandle handle);

#ifdef __cplusplus
}
#endif

/*
 * IMPORTANT NOTES FOR CHARACTER FILTERING:
 *
 * 1. Character whitelist/blacklist ONLY works with Legacy OCR engine (OEM 0)
 * 2. LSTM engine (OEM 1) completely ignores character filtering
 * 3. To use character filtering you MUST:
 *    - Set OEM to 0 (Legacy) before or after Init
 *    - Then set your whitelist/blacklist
 * 4. Legacy engine is less accurate than LSTM but supports character filtering
 * 5. Example usage for numbers only:
 *    tesseract_set_oem(handle, 0);  // Legacy engine
 *    tesseract_set_whitelist(handle, "0123456789");
 *
 * PSM (Page Segmentation Mode) values:
 * 0  = Orientation and script detection (OSD) only
 * 1  = Automatic page segmentation with OSD
 * 2  = Automatic page segmentation, but no OSD, or OCR
 * 3  = Fully automatic page segmentation, but no OSD (default)
 * 4  = Assume a single column of text of variable sizes
 * 5  = Assume a single uniform block of vertically aligned text
 * 6  = Assume a single uniform block of text
 * 7  = Treat the image as a single text line
 * 8  = Treat the image as a single word
 * 9  = Treat the image as a single word in a circle
 * 10 = Treat the image as a single character
 * 11 = Sparse text. Find as much text as possible in no particular order
 * 12 = Sparse text with OSD
 * 13 = Raw line. Treat the image as a single text line, bypassing hacks
 *
 * OEM (OCR Engine Mode) values:
 * 0 = Legacy engine only (required for character filtering)
 * 1 = Neural nets LSTM engine only (ignores character filtering)
 * 2 = Legacy + LSTM engines
 * 3 = Default, based on what is available
 */

#endif
