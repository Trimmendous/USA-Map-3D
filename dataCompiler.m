% Gets the amount of unique occurence of each state
function stateCounts = dataCompiler(csvPath)
    if nargin < 1
        csvPath = fullfile(fileparts(mfilename('fullpath')), 'banklist.csv');
    end
    fid = fopen(csvPath, 'r');
    if fid < 0
        error('dataCompiler:MissingFile', 'Cannot open %s', csvPath);
    end
    cleanup = onCleanup(@() fclose(fid));
    % %q handles quoted CSV fields containing commas in MATLAB and Octave.
    data = textscan(fid, '%q%q%q%q%q%q%q', 'Delimiter', ',', ...
                    'HeaderLines', 1, 'EndOfLine', '\n');

    % Defines the start and end dates to read from the csv
    startDate = datenum(2000, 1, 1);
    endDate = datenum(2023, 12, 31);
    months = {'Jan','Feb','Mar','Apr','May','Jun', ...
              'Jul','Aug','Sep','Oct','Nov','Dec'};

    % Creates a map to convert state acronyms to full names for all 50 states
    stateAcronymToFull = containers.Map( ...
        {'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA', ...
         'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD', ...
         'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ', ...
         'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC', ...
         'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY'}, ...
        {'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado', 'Connecticut', ...
         'Delaware', 'Florida', 'Georgia', 'Hawaii', 'Idaho', 'Illinois', 'Indiana', 'Iowa', ...
         'Kansas', 'Kentucky', 'Louisiana', 'Maine', 'Maryland', 'Massachusetts', 'Michigan', ...
         'Minnesota', 'Mississippi', 'Missouri', 'Montana', 'Nebraska', 'Nevada', 'New Hampshire', ...
         'New Jersey', 'New Mexico', 'New York', 'North Carolina', 'North Dakota', 'Ohio', 'Oklahoma', ...
         'Oregon', 'Pennsylvania', 'Rhode Island', 'South Carolina', 'South Dakota', 'Tennessee', ...
         'Texas', 'Utah', 'Vermont', 'Virginia', 'Washington', 'West Virginia', 'Wisconsin', 'Wyoming'});

    numRows = numel(data{3});

    % Initializes a map to store the state counts
    stateCounts = containers.Map('KeyType', 'char', 'ValueType', 'double');

    for i = 1:numRows
        % Match the original 2000 pivot explicitly, without datetime/toolboxes.
        parts = strsplit(strtrim(data{6}{i}), '-');
        if numel(parts) ~= 3
            error('dataCompiler:InvalidDate', 'Invalid closing date at row %d', i + 1);
        end
        year = str2double(parts{3});
        if numel(parts{3}) == 2
            year = 2000 + year;
        end
        month = find(strcmpi(parts{2}, months), 1);
        if isempty(month) || isnan(year) || isnan(str2double(parts{1}))
            error('dataCompiler:InvalidDate', 'Invalid closing date at row %d', i + 1);
        end
        currentDate = datenum(year, month, str2double(parts{1}));

        isWithinRange =  (currentDate >= startDate) & (currentDate <= endDate);

        currentStateAcronym = strtrim(data{3}{i});

        if isWithinRange
           % Checks if the state acronym is in the dictionary
            if isKey(stateAcronymToFull, currentStateAcronym)
                currentState = stateAcronymToFull(currentStateAcronym);

                % Updates the count for the current state
                if isKey(stateCounts, currentState)
                    stateCounts(currentState) = stateCounts(currentState) + 1;
                else
                    stateCounts(currentState) = 1;
                end
            else
                disp(['State acronym not found in the dictionary: ' currentStateAcronym]);
            end
        end
    end
end
