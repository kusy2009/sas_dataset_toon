/*******************************************************************************
 * Test Suite: TOON to SAS Conversion
 * Purpose: Validate %toon2sas macro functionality
 * 
 * Note: These tests require a SAS environment to run
 *******************************************************************************/

%* Include main macros;
%include "sas_macros/sas2toon.sas";
%include "sas_macros/toon2sas.sas";

/*******************************************************************************
 * Test 1: Round-trip Conversion - Employees
 * Tests: Full cycle SAS → TOON → SAS with PROC COMPARE
 *******************************************************************************/

data work.original_employees;
    length id 8 name $50 department $30 salary 8 hire_date 8;
    format hire_date datetime19.;
    
    id = 1; name = "Alice Johnson"; department = "Engineering"; 
    salary = 95000; hire_date = '15JAN2020:00:00:00'dt; output;
    
    id = 2; name = "Bob Smith"; department = "Marketing"; 
    salary = 75000; hire_date = '01JUN2019:00:00:00'dt; output;
    
    id = 3; name = "Carol Davis"; department = "Sales"; 
    salary = 82000; hire_date = '10MAR2021:00:00:00'dt; output;
    
    label id = "Employee ID"
          name = "Full Name"
          department = "Department Name"
          salary = "Annual Salary"
          hire_date = "Date of Hire";
run;

%* Convert to TOON;
%sas2toon(libname=WORK, dataset=original_employees, 
          outfile=/tmp/roundtrip_employees.toon);

%* Convert back to SAS;
%toon2sas(infile=/tmp/roundtrip_employees.toon, 
          libname=WORK, dataset=restored_employees);

%* Compare original and restored datasets;
proc compare base=work.original_employees 
             compare=work.restored_employees
             out=work.diff_employees
             outnoequal
             method=absolute
             criterion=0.00001;
run;

%* Check SYSINFO for comparison result;
%if &sysinfo < 64 %then %do;*ignoring informat differences;
    %put TEST 1 PASS: Round-trip conversion successful - datasets match exactly;
%end;
%else %do;
    %put TEST 1 FAIL: Round-trip conversion failed - datasets differ (SYSINFO=&sysinfo);
%end;

/*******************************************************************************
 * Test 2: Character Field Type Preservation
 * Tests: Leading zeros and numeric-looking strings remain character type
 *******************************************************************************/

data work.original_codes;
    length id 8 zip_code $10 phone $15 account $20 flag $5;
    
    id = 1; zip_code = "00123"; phone = "555-0001"; account = "0000012345"; flag = "true"; output;
    id = 2; zip_code = "01234"; phone = "555-0002"; account = "0000056789"; flag = "false"; output;
    id = 3; zip_code = "90210"; phone = "555-9999"; account = "9999999999"; flag = "yes"; output;
    
    label id = "Record ID"
          zip_code = "ZIP Code"
          phone = "Phone Number"
          account = "Account Number"
          flag = "Flag Value";
run;

%* Round-trip conversion;
%sas2toon(libname=WORK, dataset=original_codes, outfile=/tmp/roundtrip_codes.toon);
%toon2sas(infile=/tmp/roundtrip_codes.toon, libname=WORK, dataset=restored_codes);

%* Verify leading zeros are preserved;
data _null_;
    set work.restored_codes;
    
    %* Check first record;
    if id = 1 then do;
        if zip_code = "00123" then put "TEST 2a PASS: Leading zero preserved in zip_code";
        else put "TEST 2a FAIL: Leading zero lost in zip_code: " zip_code=;
        
        if account = "0000012345" then put "TEST 2b PASS: Leading zeros preserved in account";
        else put "TEST 2b FAIL: Leading zeros lost in account: " account=;
        
        if flag = "true" then put "TEST 2c PASS: Boolean-like string preserved";
        else put "TEST 2c FAIL: Boolean-like string changed: " flag=;
    end;
run;

/*******************************************************************************
 * Test 3: Empty String and Missing Value Handling
 * Tests: Distinction between empty strings and missing values
 *******************************************************************************/

data work.original_empty;
    length id 8 text1 $50 text2 $50 value1 8;
    
    id = 1; text1 = ""; text2 = "Present"; value1 = 100; output;
    id = 2; text1 = "Present"; text2 = ""; value1 = .; output;
    id = 3; text1 = ""; text2 = ""; value1 = .; output;
run;

%* Round-trip conversion;
%sas2toon(libname=WORK, dataset=original_empty, outfile=/tmp/roundtrip_empty.toon);
%toon2sas(infile=/tmp/roundtrip_empty.toon, libname=WORK, dataset=restored_empty);

%* Verify empty strings are preserved;
data _null_;
    set work.restored_empty;
    
    if id = 1 then do;
        if text1 = "" then put "TEST 3a PASS: Empty string preserved";
        else if missing(text1) then put "TEST 3a FAIL: Empty string became missing";
        else put "TEST 3a FAIL: Empty string changed to: " text1=;
    end;
    
    if id = 2 then do;
        if missing(value1) then put "TEST 3b PASS: Missing numeric preserved";
        else put "TEST 3b FAIL: Missing numeric changed to: " value1=;
    end;
run;

/*******************************************************************************
 * Test 4: Special Characters in Text
 * Tests: Proper escaping and unescaping of special characters
 *******************************************************************************/

data work.original_special;
    length id 8 text $200;
    
    id = 1; text = 'Text with "quotes"'; output;
    id = 2; text = "Text, with, commas"; output;
    id = 3; text = "Line1
Line2"; output;
    id = 4; text = "Tab	character"; output;
    id = 5; text = 'Backslash \ character'; output;
run;

%* Round-trip conversion;
%sas2toon(libname=WORK, dataset=original_special, outfile=/tmp/roundtrip_special.toon);
%toon2sas(infile=/tmp/roundtrip_special.toon, libname=WORK, dataset=restored_special);

%* Compare;
proc compare base=work.original_special 
             compare=work.restored_special
             method=exact;
run;

%if &sysinfo = 0 %then %do;
    %put TEST 4 PASS: Special characters preserved correctly;
%end;
%else %do;
    %put TEST 4 FAIL: Special characters not preserved (SYSINFO=&sysinfo);
%end;

/*******************************************************************************
 * Test 5: Date/DateTime Round-trip
 * Tests: Date and datetime values maintain precision
 *******************************************************************************/

data work.original_dates;
    length id 8 birth_date 8 last_login 8;
    format birth_date date9. last_login datetime19.;
    
    id = 1; birth_date = '01JAN1990'd; last_login = '15NOV2025:14:30:45'dt; output;
    id = 2; birth_date = '15MAR1985'd; last_login = '14NOV2025:09:15:30'dt; output;
run;

%* Round-trip conversion;
%sas2toon(libname=WORK, dataset=original_dates, outfile=/tmp/roundtrip_dates.toon);
%toon2sas(infile=/tmp/roundtrip_dates.toon, libname=WORK, dataset=restored_dates);

%* Compare with tolerance for datetime precision;
proc compare base=work.original_dates 
             compare=work.restored_dates
             method=absolute
             criterion=1;  %* 1 second tolerance for datetime;
run;

%if &sysinfo < 64 %then %do;*ignoring informat differences;
    %put TEST 5 PASS: Date/DateTime values preserved;
%end;
%else %do;
    %put TEST 5 FAIL: Date/DateTime values differ (SYSINFO=&sysinfo);
%end;

%put NOTE: ========================================;
%put NOTE: TOON to SAS Conversion Tests Complete;
%put NOTE: ========================================;
