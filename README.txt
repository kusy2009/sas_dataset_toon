================================================================================
SAS to TOON Converter - SAS Macro Package
================================================================================

Version: 1.0
Date: November 15, 2025

This package contains SAS macros for converting between SAS datasets and 
TOON (Token-Oriented Object Notation) format.

================================================================================
CONTENTS
================================================================================

macros/
  - sas2toon.sas        		Main macro to convert SAS dataset to TOON format
  - toon2sas.sas        		Main macro to convert TOON file to SAS dataset

tests/
  - test_sas2toon.sas   		Test suite for SAS to TOON conversion
  - test_toon2sas.sas   		Test suite for TOON to SAS conversion

TOON_format_specification.txt    	TOON format specification

================================================================================
QUICK START
================================================================================

1. Copy macros to your SAS environment:
   - Include sas2toon.sas and toon2sas.sas in your session

2. Convert SAS dataset to TOON:
   %sas2toon(libname=WORK, dataset=MYDATASET, outfile=/path/to/output.toon);

3. Convert TOON to SAS dataset:
   %toon2sas(infile=/path/to/input.toon, libname=WORK, dataset=NEWDATA);

================================================================================
REQUIREMENTS
================================================================================

- SAS 9.4 or later
- BASE SAS license
- File system access for reading/writing TOON files

================================================================================
SUPPORT
================================================================================

For issues or questions about TOON, refer to the TOON format specification documentation.
For SAS macros issues or questions, Please raise your issues directly here.

================================================================================
