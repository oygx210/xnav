function [v_diff,V] = rrFun_ta(C,obsv,pulsar,mu,dt,testing)
%RRFUN_TA Is the objective function for range-rate hodograph fitting.
%
% Author:
%   Tiger Hou
%
% Note: 
%   This version uses timing to guess range-rate values, whereas the
%   previous version used range-rate values to guess timing.
%
% Variables:
%   C      - 1x5 array, optimization variable
%            |- C(1) - x-offset of hodograph
%            |- C(2) - y-offset of hodograph
%            |- C(3) - z-offset of hodograph
%            |- C(4) - hodograph rotation along axis uc, where
%                      uc is defined by the origin and hodograph center
%            |- C(5) - radius of hodograph
%   obsv   - 1xN array of range-rate measurements
%   pulsar - 3xN matrix of N pulsars corresponding to the N measurements
%   mu     - gravitational parameter of central body
%   dt     - 1x(N-1) array of true time intervals between measurements
%
% Outputs:
%   v_diff - range-rate difference between guess and true values
%   V      - velocities corresponding to hodograph defined by C

x = C(1); % x-offset of hodograph
y = C(2); % y-offset of hodograph
z = C(3); % z-offset of hodograph
theta = C(4); % hodograph rotation w.r.t line thru origin and center
              % where theta = 0 is defined by the point where the
              % orbit normal crosses the z-axis in the inertial frame
R = C(5); % radius of hodograph

e = sqrt(x^2 + y^2 + z^2) / R; % eccentricity

% find k, the orbit normal vector
uc = [x;y;z] / norm([x;y;z]);
ue = cross([0;0;1],uc);
ue = ue / norm(ue);
k0 = cross(uc,ue);
k  = rotVec(k0,uc,theta);
ue = cross(k,uc);

% calculate the rotation matrix T that moves the hodograph to 2D
% with uc along the x-axis
T = [uc';ue';k';];

% calculate the pulsar direction in new hodograph frame
pulsar = T * pulsar;

% calculate the new hodograph center
c_vect = T * [x;y;z];
cx = c_vect(1);
cy = c_vect(2);

% find the intercept of the first range-rate measurement to get starting TA
% --- calculate perpendicular line

P1 = obsv(1) * pulsar(:,1) * norm(pulsar(:,1))^2 / norm(pulsar(1:2,1))^2;
P2 = P1 + cross([0;0;1],P1);

% --- intercept line and circle
dx = P2(1) - P1(1);
dy = P2(2) - P1(2);
dr = sqrt(dx^2+dy^2);
D = (P1(1)-cx)*(P2(2)-cy) - (P2(1)-cx)*(P1(2)-cy);
sgn = sign(dy); if sgn == 0, sgn = 1; end
delta = R^2*dr^2-D^2;

% --- no intercept, return objective function as a metric of how close the
%     line is to the circle
if delta < 0
    v_diff = ones(1,size(obsv,2)) * sqrt(-delta) * 10 + obsv * 2;
    V = nan;
    return
end

V1 = zeros(3,1);
V2 = zeros(3,1);

V1(1) = ( D*dy + sgn*dx*sqrt(delta) ) / dr^2 + cx;
V1(2) = (-D*dx + sgn*dy*sqrt(delta) ) / dr^2 + cy;
V2(1) = ( D*dy - sgn*dx*sqrt(delta) ) / dr^2 + cx;
V2(2) = (-D*dx - sgn*dy*sqrt(delta) ) / dr^2 + cy;

% use time interval to calculate subsequent velocities
% and project on to pulsars

% --- solve for all anomalies at first observation (two cases)
r1 = V1 - c_vect;
r2 = V2 - c_vect;
f1 = atan2(norm(cross(c_vect,r1)),dot(c_vect,r1));
f2 = atan2(norm(cross(c_vect,r2)),dot(c_vect,r2));
if dot(k,cross(c_vect,r1))<0, f1 = 2*pi-f1; end
if dot(k,cross(c_vect,r2))<0, f2 = 2*pi-f2; end
E1 = 2 * atan(sqrt((1-e)/(1+e))*tan(f1/2));
E2 = 2 * atan(sqrt((1-e)/(1+e))*tan(f2/2));
M1 = E1 - e*sin(E1);
M2 = E2 - e*sin(E2);
a =  mu/(V1'*V1) * (1 + e^2 + 2*e*cos(f1)) / (1 - e^2);
% a =  mu/(V2'*V2) * (1 + e^2 + 2*e*cos(f2)) / (1 - e^2);
period = sqrt(a^3/mu); % this is orbital period divided by 2*pi

% --- solve for four combinations of velocities
%     and their projections onto the pulsars
V  = nan(3,size(obsv,2),4);
Vp = nan(3,size(obsv,2),4);

V(:,1,1) = V1; M = M1;
for i = 1:size(obsv,2)
    if i ~= 1, M = M + dt(i-1)/period; end
    M = mod(M,2*pi);
    E = kepler(M,e);
    f = 2*atan(sqrt((1+e)/(1-e))*tan(E/2));
    df = f - f1;
    V(:,i,1) = rotz(rad2deg(df)) * (V1-c_vect) + c_vect;
    Vp(:,i,1) = dot(V(:,i,1),pulsar(:,i))/norm(pulsar(:,i))^2*pulsar(:,i);
end

V(:,1,2) = V1; M = M1;
for i = 1:size(obsv,2)
    if i ~= 1, M = M - dt(i-1)/period; end
    M = mod(M,2*pi);
    E = kepler(M,e);
    f = 2*atan(sqrt((1+e)/(1-e))*tan(E/2));
    df = f - f1;
    V(:,i,2) = rotz(rad2deg(df)) * (V1-c_vect) + c_vect;
    Vp(:,i,2) = dot(V(:,i,2),pulsar(:,i))/norm(pulsar(:,i))^2*pulsar(:,i);
end

V(:,1,3) = V2; M = M2;
for i = 1:size(obsv,2)
    if i ~= 1, M = M + dt(i-1)/period; end
    M = mod(M,2*pi);
    E = kepler(M,e);
    f = 2*atan(sqrt((1+e)/(1-e))*tan(E/2));
    df = f - f2;
    V(:,i,3) = rotz(rad2deg(df)) * (V2-c_vect) + c_vect;
    Vp(:,i,3) = dot(V(:,i,3),pulsar(:,i))/norm(pulsar(:,i))^2*pulsar(:,i);
end

V(:,1,4) = V2; M = M2;
for i = 1:size(obsv,2)
    if i ~= 1, M = M - dt(i-1)/period; end
    M = mod(M,2*pi);
    E = kepler(M,e);
    f = 2*atan(sqrt((1+e)/(1-e))*tan(E/2));
    df = f - f2;
    V(:,i,4) = rotz(rad2deg(df)) * (V2-c_vect) + c_vect;
    Vp(:,i,4) = dot(V(:,i,4),pulsar(:,i))/norm(pulsar(:,i))^2*pulsar(:,i);
end

% --- compare projections with observations
Vd = reshape(vecnorm(Vp-pulsar.*obsv,2,1),size(obsv,2),4)';
Vd_norm = vecnorm(Vd,2,2);
idx = find(Vd_norm == min(Vd_norm));
idx = idx(1);
v_diff = Vd(idx,:);
V = V(:,:,idx);

%------------ TESTING --------------
if exist('testing','var')
    % convert everything to 2D
    uc = T * uc;
    ue = T * ue;
    k  = T * k;
    k0 = T * k0;

    figure
    % --- calculate points on hodograph
    angles = linspace(0,2*pi,100);
    cX = R * cos(angles) + c_vect(1);
    cY = R * sin(angles) + c_vect(2);
    circ = [cX;cY;zeros(size(cX))];
    % --- plot hodograph
    plot3(circ(1,:),circ(2,:),circ(3,:),'DisplayName','Hodograph');
    hold on
    % --- plot inertial axes
    quiver3([0,0,0],[0,0,0],[0,0,0],[1,0,0],[0,1,0],[0,0,1],'Color','Black','DisplayName','Axes')
    % --- plot circle center vector uc
    quiver3(0,0,0,uc(1),uc(2),uc(3),'DisplayName','uc');
    % --- plot eccentricity vector ue
    quiver3(0,0,0,ue(1),ue(2),ue(3),'DisplayName','ue')
    % --- plot hodograph normal at theta = 0
    quiver3(0,0,0,k0(1),k0(2),k0(3),'DisplayName','k0')
    % --- plot true hodograph normal
    quiver3(0,0,0,k(1),k(2),k(3),'DisplayName','k')
    % --- plot pulsar vector
    quiver3(0,0,0,pulsar(1,1),pulsar(2,1),pulsar(3,1),'-.','LineWidth',1,'DisplayName','P1')
    quiver3(0,0,0,pulsar(1,2),pulsar(2,2),pulsar(3,2),'--','LineWidth',1,'DisplayName','P2')
    quiver3(0,0,0,pulsar(1,3),pulsar(2,3),pulsar(3,3),':' ,'LineWidth',1,'DisplayName','P3')
    % --- plot guess velocities
    scatter3(V(1,:),V(2,:),V(3,:),'DisplayName','Guess Obsv Positions')
    hold off
    xlabel('x');ylabel('y');zlabel('z');legend
    axis equal
    view([1 1 1])
end
%------------ END TEST -------------

% --- final processing of outputs
V = T' * V; % back to 3D frame

end

function E = kepler(M,e)

if M == 0
    E = 0;
    return
end

E = M + e/2;
d = 1;
while d > 1e-6
    Ep = E;
    E = E - (E-e*sin(E)-M)/(1-e*cos(E));
    d = abs(Ep-E)/Ep;
end

end