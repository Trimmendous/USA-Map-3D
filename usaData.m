function [values, names] = usaData(data, varargin)
% USADATA Normalize almost any state-keyed dataset to a 50x1 value vector.
%
%   values = usaData(data)                     values(i) belongs to usaStates(){i}
%   values = usaData('file.csv', 'ValueColumn', 'Deposits', 'Aggregate', 'sum')
%
% Accepted DATA:
%   50-element numeric vector       alphabetical state order (see usaStates)
%   containers.Map                  'CA' -> 3, 'New York' -> 7, ...
%   scalar struct                   struct('CA', 3, 'New_York', 7)
%   struct array / table            one row per record: a state field plus a value field
%   {keys, values}                  cell of state keys and a numeric vector
%   cellstr of keys                 one entry per record; rows are counted
%   'path/to/file.csv'              header row required; see options
%
% Keys may be postal codes or names in any case, with spaces or underscores.
% Repeated keys are combined with Aggregate. States without data are NaN
% (0 when counting). Keys that are not one of the 50 states (PR, DC, ...)
% are skipped with a single warning.
%
% Options:
%   'StateColumn'  column/field holding the state key (default: auto-detect
%                  State, Name, Code, Abbreviation, ...)
%   'ValueColumn'  column/field holding the value (default: Value, or the only
%                  numeric field; for CSV files, none -> count rows)
%   'Aggregate'    'sum' (default with values) | 'count' (default without)
%                  | 'mean' | 'max' | 'min'
opts = parseOptions(varargin, struct('StateColumn', '', 'ValueColumn', '', 'Aggregate', ''));
names = usaStates();

if isnumeric(data) && numel(data) == 50
    values = double(data(:));
    return;
end
if exist('istable', 'builtin') || exist('istable', 'file')
    if istable(data), data = table2struct(data); end
end

keys = {}; raw = [];
if isa(data, 'containers.Map')
    keys = data.keys(); raw = cell2mat(data.values());
elseif ischar(data) || (exist('isstring', 'builtin') && isstring(data))
    [keys, raw] = readCsv(char(data), opts);
elseif isstruct(data) && isscalar(data) && isempty(pickField(fieldnames(data), opts.StateColumn, stateAliases()))
    keys = fieldnames(data)'; raw = cellfun(@double, struct2cell(data))';
elseif isstruct(data)
    [keys, raw] = fromRecords(data, opts);
elseif iscell(data) && numel(data) == 2 && iscellstr(data{1}) && isnumeric(data{2})
    keys = data{1}; raw = double(data{2});
elseif iscell(data) && size(data, 2) == 2 && iscellstr(data(:, 1))
    keys = data(:, 1); raw = cellfun(@double, data(:, 2));
elseif iscellstr(data)
    keys = data;
else
    error('usaData:UnsupportedInput', ...
        'Unsupported data: pass a 50-vector, Map, struct, table, cell, or CSV path.');
end
values = aggregate(keys(:), raw(:), opts.Aggregate);
end

function values = aggregate(keys, raw, mode)
[index, unknown] = stateIndex(keys);
if ~isempty(unknown)
    warning('usaData:UnknownKeys', 'Skipped %d record(s) with non-state keys: %s', ...
        numel(unknown), strjoin(unique(unknown(:)'), ', '));
end
if isempty(mode)
    if isempty(raw), mode = 'count'; else, mode = 'sum'; end
end
keep = index > 0;
index = index(keep);
if strcmpi(mode, 'count')
    values = accumarray(index, 1, [50 1]);
    return;
end
if isempty(raw), error('usaData:NoValues', 'Aggregate ''%s'' needs a value column.', mode); end
raw = raw(keep);
fns = struct('sum', @sum, 'mean', @mean, 'max', @max, 'min', @min);
if ~isfield(fns, lower(mode)), error('usaData:BadAggregate', 'Unknown Aggregate ''%s''.', mode); end
values = accumarray(index, raw, [50 1], fns.(lower(mode)), NaN);
end

function [index, unknown] = stateIndex(keys)
% Map any spelling of a state name or postal code to its alphabetical index.
[names, codes] = usaStates();
normalize = @(s) upper(regexprep(s, '[^A-Za-z]', ''));
lookup = [normalize(names); normalize(codes)];
[found, where] = ismember(normalize(strtrim(keys)), lookup);
index = mod(where - 1, 50) + 1;
index(~found) = 0;
unknown = keys(~found);
end

function [keys, raw] = fromRecords(s, opts)
fields = fieldnames(s);
stateField = pickField(fields, opts.StateColumn, stateAliases());
if isempty(stateField), error('usaData:NoStateField', 'Cannot find a state field; set ''StateColumn''.'); end
keys = {s.(stateField)};
valueField = pickField(fields, opts.ValueColumn, {'value'});
if isempty(valueField)
    numeric = fields(cellfun(@(f) isnumeric(s(1).(f)), fields));
    if numel(numeric) == 1, valueField = numeric{1}; end
end
raw = [];
if ~isempty(valueField), raw = toNumber({s.(valueField)}); end
end

function [keys, raw] = readCsv(path, opts)
fid = fopen(path, 'r');
if fid < 0, error('usaData:MissingFile', 'Cannot open %s', path); end
cleanup = onCleanup(@() fclose(fid));
line = fgetl(fid);
line(double(line) > 127) = [];   % e.g. stray 0xA0 bytes in exported headers
header = regexp(line, ',(?=(?:[^"]*"[^"]*")*[^"]*$)', 'split');
header = strrep(header, '"', '');
% %q handles quoted fields containing commas in MATLAB and Octave.
columns = textscan(fid, repmat('%q', 1, numel(header)), 'Delimiter', ',', 'EndOfLine', '\n');
stateColumn = pickField(header, opts.StateColumn, stateAliases());
if isempty(stateColumn), error('usaData:NoStateColumn', 'Cannot find a state column in %s; set ''StateColumn''.', path); end
keys = columns{strcmp(header, stateColumn)};
raw = [];
if ~isempty(opts.ValueColumn)
    valueColumn = pickField(header, opts.ValueColumn, {});
    if isempty(valueColumn), error('usaData:NoValueColumn', 'No column ''%s'' in %s.', opts.ValueColumn, path); end
    raw = toNumber(columns{strcmp(header, valueColumn)});
end
end

function name = pickField(fields, requested, aliases)
% Match ignoring case, spaces, punctuation and stray bytes (e.g. 0xA0 in headers).
simple = @(s) lower(regexprep(s, '[^A-Za-z0-9]', ''));
candidates = aliases;
if ~isempty(requested), candidates = {requested}; end
name = '';
for c = candidates
    hit = find(strcmp(simple(fields), simple(c{1})), 1);
    if ~isempty(hit), name = fields{hit}; return; end
end
end

function aliases = stateAliases()
aliases = {'state', 'statename', 'stateabbr', 'stateabbreviation', 'statecode', ...
    'st', 'name', 'code', 'abbreviation', 'postal', 'region'};
end

function x = toNumber(c)
if isnumeric(c), x = double(c(:)); return; end
if all(cellfun(@isnumeric, c)), x = cellfun(@double, c(:)); return; end
x = str2double(regexprep(c(:), '[$,%\s]', ''));
end

function opts = parseOptions(args, opts)
for k = 1:2:numel(args)
    name = fieldnames(opts);
    hit = strcmpi(name, args{k});
    if ~any(hit), error('usaData:BadOption', 'Unknown option ''%s''.', args{k}); end
    opts.(name{hit}) = args{k + 1};
end
end
