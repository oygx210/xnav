clear;clc

addpath('..\functions')

f0 = deg2rad(180);

dfvect = deg2rad([10,15,30,60,90,120,150,180,210,240,270,300,330]);

numObsv = 3;

mu = 1;
a = 1;
e = 0.9;
i = deg2rad(45);
omg = deg2rad(0);
w = deg2rad(0);
noise = 0.0001;
orbitParams = [a,e,i,omg,w,0];

selObsv = 1;
numSims = 2000;
v = nan(numObsv,3);
errVect = nan(numSims,length(dfvect));

for i = 1:length(dfvect)
    fvect = linspace(f0,f0+dfvect(i),numObsv);
    for s = 1:numSims
        nvect = randn(numObsv,3) * noise;
        for j = 1:numObsv
            orbitParams(6) = fvect(j);
            [~,v(j,:)] = Get_Orb_Vects(orbitParams,mu);
        end
        orbitParams(6) = fvect(selObsv);
        rRef = Get_Orb_Vects(orbitParams,mu);
        r = hodo(v+nvect,mu);
        r = r(selObsv,:)';
        errVect(s,i) = norm(r-rRef) / norm(rRef);
    end
end
hold on
plot(dfvect,mean(errVect).*dfvect.^0.5)
hold off
xlabel('df')
ylabel('error metric')