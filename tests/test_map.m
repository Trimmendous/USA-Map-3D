function test_map()
% Run from the project folder: addpath('tests'); test_map
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root);
states = loadStateBoundaries();
assert(numel(states) == 50);
assert(numel(unique({states.Name})) == 50);
counts = dataCompiler();
assert(sum(cell2mat(values(counts))) == 563);
assert(counts('Georgia') == 93 && counts('Florida') == 76);
assert(counts('Hawaii') == 1);
assert(norm(lambertUSA(-96,39)) < 1e-12);
parts = 0;
for i = 1:numel(states)
    for j = 1:numel(states(i).Parts)
        part = states(i).Parts(j);
        [p,f] = triangulateRing(lambertUSA(part.Lon,part.Lat,-154,63));
        if ~isempty(f)
            a = p(f(:,2),:)-p(f(:,1),:);
            b = p(f(:,3),:)-p(f(:,1),:);
            area = sum(abs(a(:,1).*b(:,2)-a(:,2).*b(:,1)))/2;
            assert(abs(area-polyarea(p(:,1),p(:,2))) < 1e-10);
        end
        parts = parts+1;
    end
end
assert(parts == 143);
% Concave polygons must retain their area without filling their indentation.
[p,f] = triangulateRing([0 0;3 0;3 1;1 1;1 3;0 3;0 0]);
assert(size(f,1) == 4 && polyarea(p(:,1),p(:,2)) == 5);
% Depth-buffer results must not depend on the order of overlapping meshes.
mesh = struct('Vertices',[0 0 0;1 0 0;1 1 0;0 1 0], ...
    'Faces',[1 2 3;1 3 4],'Color',[1 0 0],'Outline',false,'Height',0);
front = mesh; front.Vertices(:,3) = .2; front.Color = [0 1 0];
a = rasterizeMap([mesh front],[0 0 0]);
b = rasterizeMap([front mesh],[0 0 0]);
assert(isequal(a,b));
assert(any(any(a(:,:,2) == 255)));
fprintf('PASS: 50 states, 143 land parts, counts, polygon areas, and depth ordering.\n');
end
