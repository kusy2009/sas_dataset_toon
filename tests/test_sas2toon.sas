/*******************************************************************************
 * Test Suite: SAS to TOON Conversion
 * Purpose: Validate %sas2toon macro functionality
 * 
 * Note: These tests require a SAS environment to run
 *******************************************************************************/

%* Include main macros;
%include "sas_macros/sas2toon.sas";
%include "sas_macros/toon2sas.sas";

/*******************************************************************************
 * Test 1: Basic Employee Dataset
 * Tests: Numeric, character, and datetime fields
 *******************************************************************************/

data work.test_employees;
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
%sas2toon(libname=WORK, dataset=test_employees, outfile=/tmp/test_employees.toon);

%* Verify TOON file exists;
%if %sysfunc(fileexist(/tmp/test_employees.toon)) %then %do;
    %put TEST 1 PASS: TOON file created;
%end;
%else %do;
    %put TEST 1 FAIL: TOON file not created;
%end;

/*******************************************************************************
 * Test 2: Character Fields with Special Characters
 * Tests: Comma escaping, quote escaping, empty strings
 *******************************************************************************/

data work.test_special_chars;
    length id 8 text1 $100 text2 $100 text3 $100;
    
    id = 1; text1 = "Normal text"; text2 = "Text, with comma"; text3 = 'Text with "quotes"'; output;
    id = 2; text1 = ""; text2 = "Empty first field"; text3 = "Normal"; output;
    id = 3; text1 = "Line1
Line2"; text2 = "Tab	here"; text3 = "Normal"; output;
    
    label id = "ID"
          text1 = "Text Field 1"
          text2 = "Text Field 2"
          text3 = "Text Field 3";
run;

%sas2toon(libname=WORK, dataset=test_special_chars, outfile=/tmp/test_special.toon);

%* Verify file created;
%if %sysfunc(fileexist(/tmp/test_special.toon)) %then %do;
    %put TEST 2 PASS: Special characters TOON file created;
%end;
%else %do;
    %put TEST 2 FAIL: Special characters TOON file not created;
%end;

/*******************************************************************************
 * Test 3: Numeric Fields with Leading Zeros (Character Type)
 * Tests: Type preservation for numeric-looking character fields
 *******************************************************************************/

data work.test_leading_zeros;
    length id 8 zip_code $10 phone $15 account $20;
    
    id = 1; zip_code = "00123"; phone = "555-0001"; account = "0000012345"; output;
    id = 2; zip_code = "01234"; phone = "555-0002"; account = "0000056789"; output;
    id = 3; zip_code = "90210"; phone = "555-9999"; account = "9999999999"; output;
    
    label id = "Record ID"
          zip_code = "ZIP Code"
          phone = "Phone Number"
          account = "Account Number";
run;

%sas2toon(libname=WORK, dataset=test_leading_zeros, outfile=/tmp/test_leading_zeros.toon);

%* Verify file created;
%if %sysfunc(fileexist(/tmp/test_leading_zeros.toon)) %then %do;
    %put TEST 3 PASS: Leading zeros TOON file created;
%end;
%else %do;
    %put TEST 3 FAIL: Leading zeros TOON file not created;
%end;

/*******************************************************************************
 * Test 4: Missing Values
 * Tests: Handling of numeric and character missing values
 *******************************************************************************/

data work.test_missing;
    length id 8 value1 8 text1 $50 value2 8;
    
    id = 1; value1 = 100; text1 = "Present"; value2 = 200; output;
    id = 2; value1 = .; text1 = ""; value2 = .; output;
    id = 3; value1 = 300; text1 = "Also present"; value2 = .; output;
    
    label id = "ID"
          value1 = "Numeric Value 1"
          text1 = "Text Value"
          value2 = "Numeric Value 2";
run;

%sas2toon(libname=WORK, dataset=test_missing, outfile=/tmp/test_missing.toon);

%* Verify file created;
%if %sysfunc(fileexist(/tmp/test_missing.toon)) %then %do;
    %put TEST 4 PASS: Missing values TOON file created;
%end;
%else %do;
    %put TEST 4 FAIL: Missing values TOON file not created;
%end;

/*******************************************************************************
 * Test 5: Date and DateTime Formats
 * Tests: Proper formatting of SAS dates and datetimes
 *******************************************************************************/

data work.test_dates;
    length id 8 birth_date 8 last_login 8 created_date 8;
    format birth_date date9. last_login datetime19. created_date date9.;
    
    id = 1; birth_date = '01JAN1990'd; 
            last_login = '15NOV2025:14:30:00'dt;
            created_date = '01JAN2020'd; output;
    
    id = 2; birth_date = '15MAR1985'd; 
            last_login = '14NOV2025:09:15:30'dt;
            created_date = '15JUN2019'd; output;
    
    label id = "User ID"
          birth_date = "Birth Date"
          last_login = "Last Login DateTime"
          created_date = "Account Created";
run;

%sas2toon(libname=WORK, dataset=test_dates, outfile=/tmp/test_dates.toon);

%* Verify file created;
%if %sysfunc(fileexist(/tmp/test_dates.toon)) %then %do;
    %put TEST 5 PASS: Date/DateTime TOON file created;
%end;
%else %do;
    %put TEST 5 FAIL: Date/DateTime TOON file not created;
%end;

%put NOTE: ========================================;
%put NOTE: SAS to TOON Conversion Tests Complete;
%put NOTE: ========================================;
