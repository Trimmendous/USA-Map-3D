function rgb = rasterizeMap(scene, background, viewAngles, imageSize)
% RASTERIZEMAP Orthographic triangle rasterizer with a depth buffer.
% Fixed-view fallback for Octave's gnuplot toolkit, which cannot draw
% occluding 3D patches. Pure MATLAB-language code, no toolboxes.
%
%   scene.Vertices    V x 3
%   scene.Faces       F x 3 triangles
%   scene.FaceColors  F x 3 RGB in [0, 1]
%   scene.Lines       struct array: XYZ (NaN-separated polylines), Color
if nargin < 3 || isempty(viewAngles), viewAngles = [-12 55]; end
if nargin < 4, imageSize = [850 1400]; end
H = imageSize(1); W = imageSize(2);
az = viewAngles(1) * pi / 180; el = viewAngles(2) * pi / 180;
% Same camera as MATLAB's view(az, el): screen x, screen y, depth toward viewer.
R = [cos(az), sin(az), 0; ...
    -sin(el)*sin(az), sin(el)*cos(az), cos(el); ...
     cos(el)*sin(az), -cos(el)*cos(az), sin(el)];
project = @(v) v * R';
lines = scene.Lines;
if isempty(lines), lines = struct('XYZ', zeros(0, 3), 'Color', {}); end
p = project(scene.Vertices);
lineXYZ = vertcat(lines.XYZ, zeros(0, 3));
q = project(lineXYZ(all(isfinite(lineXYZ), 2), :));
lo = min([p; q]); hi = max([p; q]);
factor = min(([W H] - 50) ./ max(hi(1:2) - lo(1:2), eps));
offset = ([W H] - (hi(1:2) - lo(1:2)) * factor) / 2;
toPixels = @(v) [offset(1) + (v(:, 1) - lo(1)) * factor, ...
    H - offset(2) - (v(:, 2) - lo(2)) * factor, v(:, 3)];
p = toPixels(p);

depth = -inf(H, W);
rgb = repmat(reshape(uint8(background * 255), 1, 1, 3), H, W);
plane = H * W;
colors = uint8(scene.FaceColors * 255);
for j = 1:size(scene.Faces, 1)
    t = p(scene.Faces(j, :), :);
    left = max(1, floor(min(t(:, 1)))); right = min(W, ceil(max(t(:, 1))));
    top = max(1, floor(min(t(:, 2)))); bottom = min(H, ceil(max(t(:, 2))));
    if left > right || top > bottom, continue; end
    denominator = (t(2,2)-t(3,2))*(t(1,1)-t(3,1)) + (t(3,1)-t(2,1))*(t(1,2)-t(3,2));
    if abs(denominator) < 1e-12, continue; end
    [x, y] = meshgrid(left:right, top:bottom);
    a = ((t(2,2)-t(3,2))*(x-t(3,1)) + (t(3,1)-t(2,1))*(y-t(3,2))) / denominator;
    b = ((t(3,2)-t(1,2))*(x-t(3,1)) + (t(1,1)-t(3,1))*(y-t(3,2))) / denominator;
    c = 1 - a - b;
    z = a*t(1,3) + b*t(2,3) + c*t(3,3);
    ids = y + (x - 1) * H;
    visible = a >= -1e-9 & b >= -1e-9 & c >= -1e-9 & z >= depth(ids);
    ids = ids(visible);
    depth(ids) = z(visible);
    rgb(ids) = colors(j, 1); rgb(ids + plane) = colors(j, 2); rgb(ids + 2*plane) = colors(j, 3);
end

% Polylines, sampled at pixel spacing and clipped against the depth buffer.
tolerance = 2 / factor;
for k = 1:numel(lines)
    v = toPixels(project(lines(k).XYZ));
    a = v(1:end-1, :); b = v(2:end, :);
    ok = all(isfinite([a b]), 2);
    a = a(ok, :); b = b(ok, :);
    if isempty(a), continue; end
    n = max(2, ceil(max(abs(b(:, 1:2) - a(:, 1:2)), [], 2)) + 1);
    seg = repelem((1:size(a, 1))', n);
    t = (cumsum(ones(size(seg))) - repelem(cumsum(n) - n, n) - 1) ./ (repelem(n, n) - 1);
    pts = a(seg, :) + (b(seg, :) - a(seg, :)) .* t;
    x = round(pts(:, 1)); y = round(pts(:, 2));
    inside = x >= 1 & x <= W & y >= 1 & y <= H;
    ids = y(inside) + (x(inside) - 1) * H;
    ids = ids(pts(inside, 3) >= depth(ids) - tolerance);
    c = uint8(lines(k).Color * 255);
    rgb(ids) = c(1); rgb(ids + plane) = c(2); rgb(ids + 2*plane) = c(3);
end
end
