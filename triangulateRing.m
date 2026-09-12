function [points, faces] = triangulateRing(points)
% Ear clipping preserves concave coastlines and works without a toolbox.
% Triangular faces also allow GNU Octave's gnuplot backend to export in 3D.
points = points([true; any(diff(points, 1, 1) ~= 0, 2)], :);
if size(points, 1) > 1 && all(points(1,:) == points(end,:))
    points(end,:) = [];
end
faces = zeros(0, 3);
if size(points,1) < 3, return; end
scale = max(max(points)-min(points));
tol = max(scale^2*1e-12, eps*1e-3);
cross2 = @(a,b) a(:,1).*b(:,2)-a(:,2).*b(:,1);
% Remove straight intermediate points before ear clipping.
changed = true;
while changed && size(points,1) > 3
    changed = false;
    for i = 1:size(points,1)
        before = mod(i-2,size(points,1))+1;
        after = mod(i,size(points,1))+1;
        a = points(i,:)-points(before,:);
        b = points(after,:)-points(i,:);
        if abs(cross2(a,b)) <= tol && dot(a,b) >= 0
            points(i,:) = [];
            changed = true;
            break;
        end
    end
end
next = [2:size(points,1), 1];
area2 = sum(cross2(points, points(next,:)));
if abs(area2) <= tol, return; end
if area2 < 0, points = flipud(points); end
remaining = 1:size(points,1);
while numel(remaining) > 3
    found = false;
    for k = 1:numel(remaining)
        ids = remaining([mod(k-2,numel(remaining))+1, k, mod(k,numel(remaining))+1]);
        a = points(ids(1),:); b = points(ids(2),:); c = points(ids(3),:);
        if cross2(b-a,c-b) <= tol, continue; end
        others = remaining(~ismember(remaining,ids));
        q = points(others,:);
        inside = cross2(repmat(b-a,size(q,1),1),q-a) >= -tol & ...
                 cross2(repmat(c-b,size(q,1),1),q-b) >= -tol & ...
                 cross2(repmat(a-c,size(q,1),1),q-c) >= -tol;
        if any(inside), continue; end
        faces(end+1,:) = ids;
        remaining(k) = [];
        found = true;
        break;
    end
    if ~found
        error('usa:InvalidRing', 'Cannot triangulate a boundary ring; check for intersecting edges.');
    end
end
faces(end+1,:) = remaining;
end
