/**
 @file   toon2sas.sas
 @brief  Converts a TOON-format file into a SAS dataset with automatic schema parsing.

 @details
  The toon2sas macro takes a TOON-formatted file, parses metadata, and imports its tabular content into a SAS dataset. Parameters are validated for presence and existence before conversion begins. Internal parsing macros extract schema and column details, then read data into the specified location. Designed for integrating external TOON files as native SAS datasets using flexible library and table naming.

 <b>Syntax:</b>
 @code{.sas}
  %let result=%toon2sas(infile=, libname=, dataset=);
 @endcode

 <b>Usage:</b>
 @code{.sas}
  %* Convert a TOON file located in /data/ADSL.toon into ADAM.ADSL;
  %let result=%toon2sas(infile=/data/adsl.toon, libname=ADAM, dataset=adsl);

 %* Import a TOON file from a custom location into a permanent library; 
 %let rc=%toon2sas(infile=/external/source.toon, libname=MYLIB, dataset=RAW_TABLE);

 @endcode

 @param <b>Keyword Parameters:</b>
 @param   [in] infile= ()  Path to input TOON-format file; must exist and be readable
 @param   [out] libname= ()  Target SAS library where output dataset will be created
 @param   [out] dataset= ()  Name of SAS dataset to create in the specified library

 @calledmacros
 <ol>
 <li>_parse_metadata.sas
 <li>_parse_data_section.sas
 </ol>

 @version 1.0
 @author  Saikrishnareddy Yengannagari
*/

%macro toon2sas(infile=, libname=, dataset=);

    /* Validate required parameters: infile, libname, and dataset */
    %if %length(&infile) = 0 %then %do;
        %put ERROR: infile parameter is required;
        %return;
    %end;
    %if %length(&libname) = 0 %then %do;
        %put ERROR: libname parameter is required;
        %return;
    %end;
    %if %length(&dataset) = 0 %then %do;
        %put ERROR: dataset parameter is required;
        %return;
    %end;

    /* Check if the input TOON file exists */
    %if not %sysfunc(fileexist(&infile)) %then %do;
        %put ERROR: TOON file &infile does not exist;
        %return;
    %end;

    /* Log the start of the conversion process */
    %put NOTE: Converting TOON file to SAS dataset;
    %put NOTE: Input file: &infile;
    %put NOTE: Output dataset: &libname..&dataset;

    /* Step 1: Parse metadata from the TOON file */
    %_parse_metadata(infile=&infile);

    /* Step 2: Parse data section and create the SAS dataset */
    %_parse_data_section(infile=&infile, libname=&libname, dataset=&dataset);

    /* Log completion and summary */
    %put NOTE: SAS dataset created successfully;
    %put NOTE: &_rows_read_ rows imported;

%mend toon2sas;

%macro _parse_metadata(infile=);

    /* Assign the input file to a fileref */
    filename toonin "&infile";

    /* Declare global macro variables to store metadata */
    %global _schema_name_ _num_cols_ _num_rows_ _rows_read_ _nvars_;

    /* Predefine up to 999 variable-specific macro variables for metadata */
    %do i=1 %to 999;
        %global _varname&i _vartype&i _varlabel&i _varfmt&i _varlen&i;
    %end;

    /* Initialize metadata macro variables */
    %let _schema_name_ = ;
    %let _num_cols_ = 0;
    %let _num_rows_ = 0;
    %let _rows_read_ = 0;

    data _toon_meta_;
        infile toonin lrecl=32767 truncover;
        length line $32767 key $50 value $500 varname $100 vartype $20 varlabel $256 varfmt $50 varlen 8;
        retain varname vartype varlabel varfmt varlen;

        /* Flags to track parsing state */
        in_metadata = 0;
        in_column_info = 0;

        /* Read file line by line until EOF */
        do until(eof);
            input line $char32767.;
            eof = (line = "");
            line_trim = strip(line);

            /* Detect start of metadata section */
            if line_trim = "_metadata:" then do;
                in_metadata = 1;
                continue;
            end;

            /* Detect end of metadata section by identifying table header */
            if index(line_trim, "[") > 0 and index(line_trim, "]") > 0 and 
               index(line_trim, "{") > 0 and index(line_trim, "}") > 0 then do;
                in_metadata = 0;

                /* Output last variable's metadata before exiting */
                if varname ne "" then output;

                /* Save table header line to macro variable */
                call symputx('_table_header_', line_trim, 'G');
                leave;
            end;

            /* Parse metadata content */
            if in_metadata then do;
                indent = length(line) - length(left(line)); /* Determine indentation level */

                /* Top-level metadata keys (indent = 2) */
                if indent = 2 then do;
                    if index(line_trim, ":") > 0 then do;
                        key = scan(line_trim, 1, ":");
                        value = strip(scan(line_trim, 2, ":"));

                        /* Assign values to corresponding macro variables */
                        if key = "schema_name" then call symputx('_schema_name_', value, 'G');
                        else if key = "columns" then call symputx('_num_cols_', value, 'G');
                        else if key = "rows" then call symputx('_num_rows_', value, 'G');
                        else if key = "column_info" then in_column_info = 1; /* Start parsing column info */
                    end;
                end;

                /* Start of a new column block (indent = 4) */
                else if indent = 4 and in_column_info then do;
                    /* Output previous column's metadata before resetting */
                    if varname ne "" then output;

                    /* Initialize new column metadata */
                    varname = scan(line_trim, 1, ":");
                    vartype = "";
                    varlabel = "";
                    varfmt = "";
                    varlen = .;
                end;

                /* Column attributes (indent = 6) */
                else if indent = 6 and in_column_info then do;
                    if index(line_trim, ":") > 0 then do;
                        key = scan(line_trim, 1, ":");
                        value = strip(substr(line_trim, index(line_trim, ":")+1));

                        /* Assign attribute values to variables */
                        if key = "type" then vartype = value;
                        else if key = "label" then varlabel = value;
                        else if key = "format" then varfmt = value;
                        else if key = "length" then varlen = input(value, best32.);
                    end;
                end;
            end;
        end;

        /* Keep only relevant metadata columns */
        keep varname vartype varlabel varfmt varlen;
    run;

    /* Clear the fileref */
    filename toonin clear;

    /* Extract metadata into macro variables using SQL */
    proc sql noprint;
        select count(*) into :_nvars_ trimmed from _toon_meta_;
        select varname into :_varname1-:_varname999 from _toon_meta_;
        select vartype into :_vartype1-:_vartype999 from _toon_meta_;
        select varlabel into :_varlabel1-:_varlabel999 from _toon_meta_;
        select varfmt into :_varfmt1-:_varfmt999 from _toon_meta_;
        select varlen into :_varlen1-:_varlen999 from _toon_meta_;
    quit;

    /* Log parsed metadata summary */
    %put NOTE: Parsed metadata for &_nvars_ variables;
    %do i=1 %to &_nvars_;
        %put NOTE: Variable &&_varname&i type=&&_vartype&i length=&&_varlen&i label=&&_varlabel&i format=&&_varfmt&i;
    %end;

%mend _parse_metadata;

%macro _parse_data_section(infile=, libname=, dataset=);

    /* Declare local macro variables for building DATA step statements */
    %local i vname vtype vlabel vlen vfmt input_stmt length_stmt label_stmt format_stmt;

    /* Initialize statement builders */
    %let input_stmt=;
    %let length_stmt=;
    %let label_stmt=;
    %let format_stmt=;

    /* Loop through all parsed variables to construct SAS statements */
    %do i=1 %to &_nvars_;
        %let vname = %superq(_varname&i);

        /* Skip empty variable names to avoid syntax errors */
        %if %length(&vname) > 0 %then %do;

            /* Retrieve metadata for the current variable */
            %let vtype  = %superq(_vartype&i);
            %let vlabel = %superq(_varlabel&i);
            %let vlen   = %superq(_varlen&i);
            %let vfmt   = %superq(_varfmt&i);

            /* Build LENGTH statement based on type and length */
            %if &vtype = character %then %do;
                %if %length(&vlen) > 0 %then %do;
                    %let length_stmt = &length_stmt &vname $&vlen;
                %end;
                %else %do;
                    /* Default length for character variables if not specified */
                    %let length_stmt = &length_stmt &vname $2000;
                %end;
            %end;
            %else %do;
                /* Default length for numeric variables */
                %let length_stmt = &length_stmt &vname 8;
            %end;

            /* Build LABEL statement if label is provided */
            %if %length(&vlabel) > 0 %then %do;
                %let label_stmt = &label_stmt &vname = "&vlabel";
            %end;

            /* Build FORMAT statement if format is provided */
            %if %length(&vfmt) > 0 %then %do;
                %let format_stmt = &format_stmt &vname &vfmt;
            %end;

            /* Build INPUT statement (no informat used) */
            %let input_stmt = &input_stmt &vname;
            %let input_stmt = &input_stmt %str( );

        %end;
        %else %do;
            %put WARNING: Skipping empty variable name at index &i;
        %end;
    %end;

    /* Step 1: Determine the line number where actual data starts */
    data _null_;
        infile "&infile" lrecl=32767 truncover;
        retain line_no 0;
        length line $32767;
        line_no + 1;
        input line $char32767.;

        /* Detect header line using JSON-like structure markers */
        if index(line, "[") > 0 and index(line, "]") > 0 and 
           index(line, "{") > 0 and index(line, "}") > 0 then do;
            call symputx('data_start_line', line_no + 1); /* Data starts after header */
            stop;
        end;
    run;

    /* Step 2: Read data from the identified starting line */
    data &libname..&dataset 
        %if %length(&_dataset_label_) > 0 %then %do; 
            (label="&_dataset_label_") 
        %end;;
        
        infile "&infile" lrecl=32767 truncover dsd dlm=',' firstobs=&data_start_line end=eof;

        /* Apply constructed LENGTH, LABEL, and FORMAT statements */
        length &length_stmt;
        label &label_stmt;
        format &format_stmt;

        /* Read variables using constructed INPUT statement */
        input &input_stmt;

        /* Output each row and update row count macro variable */
        output;
        call symputx('_rows_read_', _n_, 'G');
    run;

%mend _parse_data_section;
