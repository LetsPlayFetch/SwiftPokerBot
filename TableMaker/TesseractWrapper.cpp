#include "TesseractWrapper.h"
#include <tesseract/baseapi.h>
#include <leptonica/allheaders.h>
#include <cstring>
#include <cstdlib>
#include <iostream>

extern "C" {

TesseractHandle tesseract_create(const char* datapath, const char* language) {
    tesseract::TessBaseAPI* api = new tesseract::TessBaseAPI();
    
    // Debug output
    std::cout << "Attempting to initialize Tesseract..." << std::endl;
    std::cout << "Datapath: " << (datapath ? datapath : "nullptr") << std::endl;
    std::cout << "Language: " << (language ? language : "nullptr") << std::endl;
    
    // Use nullptr for datapath to use default location
    const char* actualDatapath = (datapath && strlen(datapath) > 0) ? datapath : nullptr;
    
    // Try different initialization approaches
    int result = -1;
    
    // Try with explicit datapath first
    if (actualDatapath) {
        result = api->Init(actualDatapath, language);
        std::cout << "Init with path result: " << result << std::endl;
    }
    
    // If that failed, try with nullptr
    if (result != 0) {
        result = api->Init(nullptr, language);
        std::cout << "Init with nullptr result: " << result << std::endl;
    }
    
    if (result != 0) {
        std::cout << "Tesseract initialization failed!" << std::endl;
        delete api;
        return nullptr;
    }
    
    std::cout << "Tesseract initialized successfully!" << std::endl;
    return static_cast<TesseractHandle>(api);
}

void tesseract_destroy(TesseractHandle handle) {
    if (handle) {
        tesseract::TessBaseAPI* api = static_cast<tesseract::TessBaseAPI*>(handle);
        api->End();
        delete api;
    }
}

int tesseract_set_image_data(TesseractHandle handle,
                            unsigned char* data,
                            int width,
                            int height,
                            int bytes_per_pixel,
                            int bytes_per_line) {
    if (!handle) return 0;
    
    tesseract::TessBaseAPI* api = static_cast<tesseract::TessBaseAPI*>(handle);
    api->SetImage(data, width, height, bytes_per_pixel, bytes_per_line);
    return 1;
}

OCRResult tesseract_get_text_with_confidence(TesseractHandle handle) {
    OCRResult result = {nullptr, 0.0f};
    
    if (!handle) return result;
    
    tesseract::TessBaseAPI* api = static_cast<tesseract::TessBaseAPI*>(handle);
    
    // Get text
    char* text = api->GetUTF8Text();
    if (text) {
        // Copy to our own memory
        result.text = static_cast<char*>(malloc(strlen(text) + 1));
        strcpy(result.text, text);
        
        // Free Tesseract's copy
        delete[] text;
    }
    
    // Get confidence (0-100)
    result.confidence = api->MeanTextConf();
    
    return result;
}

void tesseract_free_ocr_result(OCRResult* result) {
    if (result && result->text) {
        free(result->text);
        result->text = nullptr;
        result->confidence = 0.0f;
    }
}

// Page Segmentation Mode functions
int tesseract_set_page_seg_mode(TesseractHandle handle, int psm) {
    if (!handle) return 0;
    
    tesseract::TessBaseAPI* api = static_cast<tesseract::TessBaseAPI*>(handle);
    api->SetPageSegMode(static_cast<tesseract::PageSegMode>(psm));
    return 1;
}

int tesseract_get_page_seg_mode(TesseractHandle handle) {
    if (!handle) return -1;
    
    tesseract::TessBaseAPI* api = static_cast<tesseract::TessBaseAPI*>(handle);
    return static_cast<int>(api->GetPageSegMode());
}

// OCR Engine Mode functions
int tesseract_set_oem(TesseractHandle handle, int oem) {
    // WARNING: Character whitelist/blacklist ONLY works with Legacy OCR engine (OEM 0)
    // LSTM engine (OEM 1) completely ignores character filtering
    // If you need character filtering, you MUST use OEM 0 (Legacy engine)
    // OEM modes: 0=Legacy only, 1=LSTM only, 2=Legacy+LSTM, 3=Default
    if (!handle) return 0;
    
    tesseract::TessBaseAPI* api = static_cast<tesseract::TessBaseAPI*>(handle);
    
    // Note: Setting OEM after Init() doesn't work reliably
    // You should set this before calling Init() or reinitialize
    std::cout << "WARNING: Setting OEM after Init may not work. Consider reinitializing." << std::endl;
    
    return api->SetVariable("tessedit_ocr_engine_mode", std::to_string(oem).c_str()) ? 1 : 0;
}

int tesseract_get_oem(TesseractHandle handle) {
    if (!handle) return -1;
    
    tesseract::TessBaseAPI* api = static_cast<tesseract::TessBaseAPI*>(handle);
    return static_cast<int>(api->oem());
}

// Generic variable setting - the power function for users
int tesseract_set_variable(TesseractHandle handle, const char* name, const char* value) {
    // WARNING: Some important notes about SetVariable:
    // 1. Character filtering (tessedit_char_whitelist/blacklist) ONLY works with Legacy OCR (OEM 0)
    // 2. LSTM engine (OEM 1) ignores character filtering completely
    // 3. Some variables must be set before Init(), others after Init()
    // 4. Setting variables will revert to defaults when you call End()
    // 5. For character filtering to work, you MUST use OEM 0 (Legacy engine)
    
    if (!handle || !name || !value) return 0;
    
    tesseract::TessBaseAPI* api = static_cast<tesseract::TessBaseAPI*>(handle);
    
    // Debug output for character filtering
    if (strcmp(name, "tessedit_char_whitelist") == 0 || strcmp(name, "tessedit_char_blacklist") == 0) {
        int currentOEM = static_cast<int>(api->oem());
        std::cout << "Setting " << name << " = '" << value << "'" << std::endl;
        std::cout << "Current OEM: " << currentOEM << std::endl;
        if (currentOEM == 1) {
            std::cout << "WARNING: Character filtering does NOT work with LSTM engine (OEM 1)!" << std::endl;
            std::cout << "You must use Legacy engine (OEM 0) for character filtering to work." << std::endl;
        }
    }
    
    bool success = api->SetVariable(name, value);
    if (!success) {
        std::cout << "Failed to set variable: " << name << " = " << value << std::endl;
    }
    
    return success ? 1 : 0;
}

// Get variable value
const char* tesseract_get_variable(TesseractHandle handle, const char* name) {
    if (!handle || !name) return nullptr;
    
    tesseract::TessBaseAPI* api = static_cast<tesseract::TessBaseAPI*>(handle);
    return api->GetStringVariable(name);
}

// Convenience functions for common character filtering
int tesseract_set_whitelist(TesseractHandle handle, const char* whitelist) {
    // WARNING: Character whitelist ONLY works with Legacy OCR engine (OEM 0)
    // LSTM engine (OEM 1) completely ignores whitelist settings
    // You MUST set OEM to 0 before using whitelist for it to work
    
    if (!handle || !whitelist) return 0;
    
    tesseract::TessBaseAPI* api = static_cast<tesseract::TessBaseAPI*>(handle);
    
    // Check current OEM and warn user
    int currentOEM = static_cast<int>(api->oem());
    if (currentOEM == 1) {
        std::cout << "ERROR: Character whitelist does NOT work with LSTM engine (OEM 1)!" << std::endl;
        std::cout << "You must use Legacy engine (OEM 0) for whitelist to work." << std::endl;
        std::cout << "Call tesseract_set_oem(handle, 0) before setting whitelist." << std::endl;
        return 0;
    }
    
    std::cout << "Setting character whitelist: '" << whitelist << "'" << std::endl;
    return tesseract_set_variable(handle, "tessedit_char_whitelist", whitelist);
}

int tesseract_set_blacklist(TesseractHandle handle, const char* blacklist) {
    // WARNING: Character blacklist ONLY works with Legacy OCR engine (OEM 0)
    // LSTM engine (OEM 1) completely ignores blacklist settings
    // You MUST set OEM to 0 before using blacklist for it to work
    
    if (!handle || !blacklist) return 0;
    
    tesseract::TessBaseAPI* api = static_cast<tesseract::TessBaseAPI*>(handle);
    
    // Check current OEM and warn user
    int currentOEM = static_cast<int>(api->oem());
    if (currentOEM == 1) {
        std::cout << "ERROR: Character blacklist does NOT work with LSTM engine (OEM 1)!" << std::endl;
        std::cout << "You must use Legacy engine (OEM 0) for blacklist to work." << std::endl;
        std::cout << "Call tesseract_set_oem(handle, 0) before setting blacklist." << std::endl;
        return 0;
    }
    
    std::cout << "Setting character blacklist: '" << blacklist << "'" << std::endl;
    return tesseract_set_variable(handle, "tessedit_char_blacklist", blacklist);
}

// Version and info functions
const char* tesseract_get_version() {
    return tesseract::TessBaseAPI::Version();
}

const char* tesseract_get_datapath(TesseractHandle handle) {
    if (!handle) return nullptr;
    
    tesseract::TessBaseAPI* api = static_cast<tesseract::TessBaseAPI*>(handle);
    return api->GetDatapath();
}

// Helper function to set up for character filtering
int tesseract_setup_for_character_filtering(TesseractHandle handle) {
    // This function sets up Tesseract for optimal character filtering
    // WARNING: This will switch to Legacy OCR engine which may be less accurate
    // but is required for character whitelist/blacklist to work
    
    if (!handle) return 0;
    
    std::cout << "Setting up Tesseract for character filtering..." << std::endl;
    std::cout << "WARNING: Switching to Legacy OCR engine (less accurate but supports filtering)" << std::endl;
    
    // Set to Legacy OCR engine (required for character filtering)
    int result = tesseract_set_variable(handle, "tessedit_ocr_engine_mode", "0");
    
    if (result) {
        std::cout << "Successfully configured for character filtering" << std::endl;
    } else {
        std::cout << "Failed to configure for character filtering" << std::endl;
    }
    
    return result;
}

}
