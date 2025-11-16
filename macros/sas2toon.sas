/**
 @file   sas2toon.sas
 @brief  Converts a SAS dataset to a TOON-format text file with metadata and row contents.

 @details
  This macro validates input parameters for SAS library, dataset, and output file path. It checks dataset existence, extracts metadata such as variable names, types, formats, lengths, and dataset label. It writes metadata and rows to an external TOON-format file, including summary information like number of columns and rows. Internal helper macros handle metadata extraction and row emission, supporting up to 999 columns per dataset.

 <b>Syntax:</b>
 @code{.sas}
  %sas2toon(libname=, dataset=, outfile=);
 @endcode

 <b>Usage:</b>
 @code{.sas}
  %* Export SDTM.DM to TOON format file dm.toon;
 %sas2toon(libname=SDTM, dataset=dm, outfile=/path/to/your/output/dm.toon);

 %* Convert sashelp.class to toon.txt in temp directory;
 %sas2toon(libname=sashelp, dataset=class, outfile=/tmp/toon.txt);

 @endcode

 @param <b>Keyword Parameters:</b>
 @param   [in] libname= ()  SAS library name containing the dataset to be converted; must exist in the current session
 @param   [in] dataset= ()  Name of the SAS dataset within the specified library to be exported; must exist
 @param   [out] outfile= ()  Path and file name for the TOON-format output file; will be created or overwritten

 @calledmacros
 <ol>
 <li>_extract_metadata.sas
 <li>_emit_column_metadata.sas
 <li>_emit_table_rows.sas
 </ol>

 @version 1.0
 @author  Saikrishnareddy Yengannagari
*/

%macro sas2toon(libname=, dataset=, outfile=);

    /* Validate required parameters */
    %if %length(&libname) = 0 %then %do;
        %put ERROR: libname parameter is required;
        %return;
    %end;
    %if %length(&dataset) = 0 %then %do;
        %put ERROR: dataset parameter is required;
        %return;
    %end;
    %if %length(&outfile) = 0 %then %do;
        %put ERROR: outfile parameter is required;
        %return;
    %end;

    /* Check if the specified dataset exists */
    %if not %sysfunc(exist(&libname..&dataset)) %then %do;
        %put ERROR: Dataset &libname..&dataset does not exist;
        %return;
    %end;

    /* Log conversion start */
    %put NOTE: Converting &libname..&dataset to TOON format;
    %put NOTE: Output file: &outfile;

    /* Step 1: Extract metadata from the SAS dataset */
    %_extract_metadata(libname=&libname, dataset=&dataset);

    /* Step 2: Count observations and variables using dataset attributes */
    %let dsid = %sysfunc(open(&libname..&dataset));
    %let nobs = %sysfunc(attrn(&dsid, nobs));     /* Number of observations */
    %let nvars = %sysfunc(attrn(&dsid, nvars));   /* Number of variables */
    %let rc = %sysfunc(close(&dsid));

    /* Step 3: Write TOON metadata section to output file */
    filename toonout "&outfile";

    data _null_;
        file toonout;

        /* Write metadata header */
        put "_metadata:";
        put "  source: SAS dataset";
        put "  schema_name: %upcase(&dataset)";
        %if %length(&_dataset_label_) > 0 %then %do;
            put "  dataset_label: &_dataset_label_";
        %end;
        put "  columns: &nvars";
        put "  rows: &nobs";
        put "  column_info:";

        /* Emit column-level metadata */
        %_emit_column_metadata();
    run;

    /* Step 4: Write actual data rows to TOON file */
    %_emit_table_rows(libname=&libname, dataset=&dataset, outfile=&outfile, 
                      nobs=&nobs, nvars=&nvars);

    /* Clear fileref */
    filename toonout clear;

    /* Log completion */
    %put NOTE: TOON file created successfully;
    %put NOTE: &nobs rows written;

%mend sas2toon;

%macro _extract_metadata(libname=, dataset=);

    /* Declare global macro variables to store metadata */
    %global _nvars_ _varlist_ _dataset_label_;

    /* Predefine up to 999 variable-specific macro variables */
    %do i=1 %to 999;
        %global _varname&i _vartype&i _varfmt&i _varlabel&i _varlen&i;
    %end;

    /* Step 1: Use PROC CONTENTS to extract metadata from the dataset */
    proc contents data=&libname..&dataset out=_meta_ noprint;
    run;

    /* Step 2: Use PROC SQL to populate macro variables with metadata */
    proc sql noprint;

        /* Count number of variables in the dataset */
        select count(*) into :_nvars_ trimmed
        from _meta_;

        /* Extract variable names ordered by position */
        select name into :_varname1-:_varname999
        from _meta_
        order by varnum;

        /* Extract variable types (1 = numeric, 2 = character) */
        select type into :_vartype1-:_vartype999
        from _meta_
        order by varnum;

        /* Extract variable labels */
        select label into :_varlabel1-:_varlabel999
        from _meta_
        order by varnum;

        /* Extract variable lengths */
        select length into :_varlen1-:_varlen999
        from _meta_
        order by varnum;

        /* Construct format strings conditionally */
        select 
            case 
                when format ne '' and formatd > 0 then catx('.', format, formatl, formatd)
                when format ne '' then cats(format, formatl, '.')
                else ''
            end
        into :_varfmt1-:_varfmt999
        from _meta_
        order by varnum;

        /* Extract dataset label from metadata dictionary */
        select memlabel into :_dataset_label_ trimmed
        from dictionary.tables
        where libname = "%upcase(&libname)" and memname = "%upcase(&dataset)";
    quit;

    /* Step 3: Build comma-separated variable list macro variable */
    %let _varlist_ = ;
    %do i=1 %to &_nvars_;
        %if &i = 1 %then %let _varlist_ = &&_varname&i;
        %else %let _varlist_ = &_varlist_,&&_varname&i;
    %end;

    /* Step 4: Clean up temporary metadata dataset */
    proc datasets library=work nolist;
        delete _meta_;
    quit;

%mend _extract_metadata;

%macro _emit_column_metadata();

    /* Loop through each variable to emit its metadata in TOON format */
    %do i=1 %to &_nvars_;
        %let vname  = &&_varname&i;
        %let vtype  = &&_vartype&i;
        %let vfmt   = &&_varfmt&i;
        %let vlabel = &&_varlabel&i;
        %let vlen   = &&_varlen&i;

        /* Emit variable name as a TOON key */
        put "    &vname:";

        /* Determine TOON type based on SAS type and format */
        %if &vtype = 1 %then %do;  /* SAS type 1 = numeric */
            
            /* Check for date-related formats */
            %if %index(%upcase(&vfmt), DATE) > 0 %then %do;

                /* Distinguish between DATETIME and DATE */
                %if %index(%upcase(&vfmt), DATETIME) > 0 or 
                    %index(%upcase(&vfmt), DTDATE) > 0 %then %do;
                    put "      type: datetime";
                %end;
                %else %do;
                    put "      type: date";
                %end;

            %end;
            %else %do;
                /* Default to numeric if no date-related format is found */
                put "      type: numeric";
            %end;

        %end;
        %else %do;  /* SAS type 2 = character */
            put "      type: character";

            /* Emit length for character variables */
            put "      length: &vlen";
        %end;

        /* Emit label if available */
        %if %length(&vlabel) > 0 %then %do;
            put "      label: &vlabel";
        %end;

        /* Emit format if available */
        %if %length(&vfmt) > 0 %then %do;
            put "      format: &vfmt";
        %end;

    %end;

%mend _emit_column_metadata;

%macro _emit_table_rows(libname=, dataset=, outfile=, nobs=, nvars=);

    data _null_;
        set &libname..&dataset end=eof;
        file "&outfile" mod; /* Append mode to continue writing after metadata */

        /* Emit table header on first row */
        if _n_ = 1 then do;
            put "%upcase(&dataset)[&nobs]{&_varlist_}:";
        end;

        length _row_ $32767;
        _row_ = "";

        /* Loop through each variable to construct a row string */
        %do i=1 %to &nvars;
            %let vname = &&_varname&i;
            %let vtype = &&_vartype&i;
            %let vfmt  = &&_varfmt&i;

            /* Add comma separator for all but the first column */
            %if &i > 1 %then %do;
                _row_ = cats(_row_, ",");
            %end;

            /* Handle numeric variables */
            %if &vtype = 1 %then %do;
                if missing(&vname) then _row_ = cats(_row_, "");
                else do;
                    /* Format datetime values */
                    %if %index(%upcase(&vfmt), DATETIME) > 0 or 
                        %index(%upcase(&vfmt), DTDATE) > 0 %then %do;
                        _row_ = cats(_row_, put(&vname, datetime19.));
                    %end;
                    /* Format date values */
                    %else %if %index(%upcase(&vfmt), DATE) > 0 %then %do;
                        _row_ = cats(_row_, put(&vname, yymmdd10.));
                    %end;
                    /* Default numeric formatting */
                    %else %do;
                        _row_ = cats(_row_, strip(put(&vname, best32.)));
                    %end;
                end;
            %end;

            /* Handle character variables */
            %else %do;
                if missing(&vname) then _row_ = cats(_row_, '""');
                else do;
                    /* Escape special characters if needed */
                    if index(&vname, ",") > 0 or index(&vname, '"') > 0 or 
                       index(&vname, '0A'x) > 0 or strip(&vname) = "" then do;
                        _temp_ = &vname;

                        /* Escape backslashes */
                        _temp_ = tranwrd(_temp_, "\", "\\");

                        /* Escape double quotes */
                        _temp_ = tranwrd(_temp_, '"', '\"');

                        /* Escape line breaks */
                        _temp_ = tranwrd(_temp_, '0A'x, "\n");
                        _temp_ = tranwrd(_temp_, '0D'x, "\r");

                        /* Wrap in quotes */
                        _row_ = cats(_row_, '"', strip(_temp_), '"');
                    end;
                    else do;
                        /* No escaping needed */
                        _row_ = cats(_row_, strip(&vname));
                    end;
                end;
            %end;
        %end;

        /* Write the constructed row to the file */
        put "  " _row_;
    run;

%mend _emit_table_rows;

