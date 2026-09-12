function rgb = rasterizeMap(meshes, background)
% Orthographic triangle rasterizer with a depth buffer, entirely MATLAB code.
% This supplies a fixed-view fallback when only Octave's gnuplot is available.
width = 1400; height = 850;
allVertices = vertcat(meshes.Vertices);
span = max(allVertices)-min(allVertices);
zScale = .32*span(1)/max(1,span(3));
az = -12*pi/180; el = 55*pi/180;
projected = cell(numel(meshes),1);
for i = 1:numel(meshes)
    v = meshes(i).Vertices;
    x = cos(az)*v(:,1)+sin(az)*v(:,2);
    y = -sin(az)*v(:,1)+cos(az)*v(:,2);
    z = v(:,3)*zScale;
    projected{i} = [x,sin(el)*y+cos(el)*z,-cos(el)*y+sin(el)*z];
end
allPoints = vertcat(projected{:});
lo = min(allPoints); hi = max(allPoints);
factor = min(( [width height]-50 )./(hi(1:2)-lo(1:2)));
offset = ([width height]-(hi(1:2)-lo(1:2))*factor)/2;
depth = -inf(height,width);
rgb = repmat(reshape(uint8(background*255),1,1,3),height,width);
for i = 1:numel(meshes)
    p = projected{i};
    p(:,1) = offset(1)+(p(:,1)-lo(1))*factor;
    p(:,2) = height-offset(2)-(p(:,2)-lo(2))*factor;
    projected{i} = p;
    for j = 1:size(meshes(i).Faces,1)
        t = p(meshes(i).Faces(j,:),:);
        left = max(1,floor(min(t(:,1)))); right = min(width,ceil(max(t(:,1))));
        top = max(1,floor(min(t(:,2)))); bottom = min(height,ceil(max(t(:,2))));
        [x,y] = meshgrid(left:right,top:bottom);
        denominator = (t(2,2)-t(3,2))*(t(1,1)-t(3,1)) + (t(3,1)-t(2,1))*(t(1,2)-t(3,2));
        if abs(denominator) < 1e-12, continue; end
        a = ((t(2,2)-t(3,2))*(x-t(3,1))+(t(3,1)-t(2,1))*(y-t(3,2)))/denominator;
        b = ((t(3,2)-t(1,2))*(x-t(3,1))+(t(1,1)-t(3,1))*(y-t(3,2)))/denominator;
        c = 1-a-b;
        z = a*t(1,3)+b*t(2,3)+c*t(3,3);
        ids = sub2ind([height width],y,x);
        visible = a >= -1e-9 & b >= -1e-9 & c >= -1e-9 & z >= depth(ids);
        ids = ids(visible);
        depth(ids) = z(visible);
        color = uint8(meshes(i).Color*255);
        for channel = 1:3
            rgb(ids+(channel-1)*height*width) = color(channel);
        end
    end
end
% Draw the original unit-height contour lines, clipped against the surface.
for i = 1:numel(meshes)
    if ~meshes(i).Outline, continue; end
    p = projected{i};
    count = size(p,1);
    for layer = 0:meshes(i).Height
        dz = (meshes(i).Height-layer)*zScale;
        ring = p([1:count,1],:);
        ring(:,2) = ring(:,2)+cos(el)*dz*factor;
        ring(:,3) = ring(:,3)-sin(el)*dz;
        for j = 1:count
            n = max(2,ceil(max(abs(ring(j+1,1:2)-ring(j,1:2))))+1);
            t = linspace(0,1,n)';
            line = ring(j,:)+(ring(j+1,:)-ring(j,:)).*t;
            x = round(line(:,1)); y = round(line(:,2));
            valid = x>=1 & x<=width & y>=1 & y<=height;
            ids = sub2ind([height width],y(valid),x(valid));
            z = line(valid,3);
            ids = ids(z >= depth(ids)-2/factor);
            color = uint8((meshes(i).Color*.55+.35)*255);
            for channel = 1:3
                rgb(ids+(channel-1)*height*width) = color(channel);
            end
        end
    end
end
end
