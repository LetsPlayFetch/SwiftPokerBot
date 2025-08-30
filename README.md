# Swift Poker Bot

This application is built to read poker tables and process the game state, then work in conjunction with a BBN and/or LLM to make profitable decisions, creating an agentic poker player.

I built this to explore automated decision-making systems and demonstrate large-scale software architecture. The system combines computer vision, multiple OCR methods, and AI reasoning to replicate a profesional poker player.

## Current Version Info:
Working prototype of table maker uploaded. Bot prototype is ready, uploading soon. 
Multiple planned updates to simplify the current codebase once core functionality is proven. A lot of the code works but is still a prototype and has many places for improvement and simplification. I have a list of planned additions, modifications, simplifications I wish to add at the bottom.


## Project Overview

There are two separate applications:
- **Table Maker** (MorningCoffee) - The region mapping and OCR testing tool
- **Poker Bot** (Coffee) - The actual decision-making system

*Originally had coffee-themed names that I'm in the process of changing.*

**Table Maker** allows you to:
- Create JSON table maps by defining regions on poker screenshots
- Explore image processing settings and OCR parameters
- Save and capture images in real time for building and refining models
- Test multiple OCR methods (Apple Vision, Tesseract, CoreML) with confidence tracking
- Export training data for custom model development

**Poker Bot**  handles:
- Reading poker table state through the mapped regions
- Processing game information into structured data for AI consumption
- Making profitable decisions using a pre-trained LLM or Bayesian Belief Network





## Technical Architecture

### Table Reader

- **Screen Capture Engine** - Real-time monitoring of poker interfaces
- **Multi-OCR Pipeline** - Apple Vision, Tesseract, and custom CoreML models
- **Region Mapping System** - Visual interface for defining table elements
- **Confidence Tracking** - Reliability scoring across all recognition methods
- **Training Data Collection** - Automated dataset generation for model improvement

### PokerBot

- **Game State Parser** - Converts visual data into structured game information
- **LLM Integration** - Uses pre-trained language models for strategic reasoning
- **Bayesian Networks** - 
- **Game Types** - NLH (8-MAX), More to Come later

## Key Features

### Advanced Computer Vision
- **Multi-modal OCR** with automatic fallback systems
- **Custom CoreML models** for card recognition (A, K, Q, J, T, 9-2)
- **Real-time confidence scoring** and accuracy tracking
- **Preprocessing optimization** for challenging poker interface elements

### Smart Decision Making
- **LLM reasoning** for complex strategic situations
- **BBN probability analysis** planned, for uncertainty management
- **Profitable play optimization** focused on long-term value generation

### Data Collection & Training
- **Rapid Collection Mode** - Batch capture with automatic tagging
- **Training Data Export** - TIFF images with ground truth for OCR training
- **CoreML Dataset Generation** - Raw images organized for custom model training
- These are 3 seperate pieces that I will combine later into a single simplified  interface

## Installation & Setup

### Prerequisites
- macOS (silicon)
- Xcode for compilation
- Screen Recording & Accessibility permissions
- Homebrew package manager

### Dependencies
```bash
brew install tesseract
```
I will be updating this potential problems you could run into, and howto fix them

## Setting Up a Table 



## Planned Backlog
