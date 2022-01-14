% detector 2 pixel size = 1.4497


distSC = 895;     % mm  distance from the membrane to the detector
% LCLS parameters
% distance from focus to first detector = 1.4986 meters
% distance from membrane to first detector = 895 mm
% focal distance of the lenses = 317.5
% LCLS pixel size pix1 = 1.44276, pix2 = 1.44978;
% EuXFEL pixel size pi1 = 1.4338673051 pix2 = 1.20776665922
pixsize = 1.44276;             % um            % um           % pixelsize in um
%pixsize2 = 1.44978;
maskDiam = 750;%1250;%750;            % diameter mask size in um  % 1270 is the max in that case

MagnLensToDet = 317/1498.6; % We use this factor to rescale the wavefront from the first detector position to the exit of the lens

dispscale = 0.5;

EkeV = 9.5;
delta = 3.776e-6;%
lambda = 1.2398/EkeV .*1e-9;
kw2 = 2*pi/lambda;

stepMot = 0.5;          % scan step of the motor in um

% export plots and cuts 
exportPlots = '/data/bm05/imaging/seb/LCLS/processing/XSS1D/plateRescaled';  % empty to not save anything, save folder otherwise
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                           for the records                               $
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~isempty(exportPlots)
    exportFileSummary = fullfile(exportPlots,'parameters_processing.txt');

    dlmwrite(exportFileSummary, 'Processing parameters for second step','delimiter', '' );
    dlmwrite(exportFileSummary, ['pixsize = ' num2str(pixsize) ' um'], '-append','delimiter', '' );
    dlmwrite(exportFileSummary, ['dist = ' num2str(distSC) ' mm'], '-append','delimiter', '' );
    dlmwrite(exportFileSummary, ['maskDiam = ' num2str(maskDiam) ' um'], '-append','delimiter', '' );
    dlmwrite(exportFileSummary, ['Energy = ' num2str(EkeV) ' keV'], '-append','delimiter', '' );
    dlmwrite(exportFileSummary, ['delta = ' num2str(delta)], '-append','delimiter', '' );
    dlmwrite(exportFileSummary, ['lambda = ' num2str(lambda) ' m'], '-append','delimiter','');
    dlmwrite(exportFileSummary, ['pixreach.V = ' num2str(pixreach) ' pixel'], '-append','delimiter', '' );
    dlmwrite(exportFileSummary, ['pixreach.H = ' num2str(pixreach) ' pixel'], '-append','delimiter', '' );
    dlmwrite(exportFileSummary, ['scanDimOrd = ' num2str(scanDimOrd)], '-append','delimiter','');   
    dlmwrite(exportFileSummary, ['ROIwidth = ' num2str(ROIwidth)], '-append','delimiter','');
    dlmwrite(exportFileSummary, ['ROI1 = ' num2str(ROI1)], '-append','delimiter','');
    %dlmwrite(exportFileSummary, 'Processed:', '-append','delimiter', '' );
end;


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                           build masks                                   $
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
n2 = 172;
barcolor = [1 1 1].*0;

msmin = min([size(dmVV);size(dmHH)]);
file3 = mean(stsampleV1(1+ offPR:end- offPR,round(ROIwidth/2)+1+ offPR:end-round(ROIwidth/2)- offPR,:),3);
file3 = file3(1:msmin(1),1:msmin(2));  

file2 = mean(stsampleH1(1+ offPR:end- offPR,round(ROIwidth/2)+1+ offPR:end-round(ROIwidth/2)- offPR,:),3);
file2 = file2(1:msmin(2),1:msmin(1));
file1 = file2' + file3;

if ~exist('Center','var'),     Center = [];        end;
[smmask, bigmask,Center] = maskbuilder(file1,maskDiam/pixsize,Center);

[JH, JV] = meshgrid(1:size(bigmask,2),1:(size(bigmask,1)));
dv1 = dmVV(min(JV(bigmask==1)):max(JV(bigmask==1)) , min(JH(bigmask==1)):max(JH(bigmask==1)));
dv2 = dmVH(min(JV(bigmask==1)):max(JV(bigmask==1)) , min(JH(bigmask==1)):max(JH(bigmask==1)));

dh1 = dmHV(min(JV(bigmask==1)):max(JV(bigmask==1)) , min(JH(bigmask==1)):max(JH(bigmask==1)));
dh2 = dmHH(min(JV(bigmask==1)):max(JV(bigmask==1)) , min(JH(bigmask==1)):max(JH(bigmask==1)));
[JHs, JVs] = meshgrid(1:size(smmask,2),1:(size(smmask,1)));
% if mean(dv1(smmask)) < 0 ,dv1 = -dv1;dv2 = -dv2;end;
% if mean(dh2(smmask)) < 0 ,dh1 = -dh1;dh2 = -dh2;end;

file1 = file1(min(JV(bigmask==1)):max(JV(bigmask==1)) , min(JH(bigmask==1)):max(JH(bigmask==1)));

dv1 = myerosion(dv1,.5,3);       dv2 = myerosion(dv2,.5,3);
dh1 = myerosion(dh1,.5,3);       dh2 = myerosion(dh2,.5,3);
% dv2 and dh1 are crossed terms
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                           put curvatures to scale                       $
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if (mean(dv1(smmask(:))) > 0) && (mean(dh2(smmask(:)) < 0)), dv2 = -dv2;dh2 = -dh2;end;
if (mean(dv1(smmask(:))) < 0) && (mean(dh2(smmask(:)) > 0)), dv1 = -dv1;dh1 = -dh1;end;

dv1 = dv1 .*stepMot;            dv2 = dv2 .*pixsize;           % in um
dh1 = dh1 .*pixsize;            dh2 = dh2 .*stepMot;           % in u


%% ----------------------------- radius calculation-----------------------------%



Rv = distSC./(1- (dv1)./(pixsize))./1000;
Rh = distSC./(1- (dh2)./(pixsize))./1000;


[Rhfit, Rvfit] = gradient_error(Rh,Rv,smmask);

Lnorme = 1;
disp(['Radius calculated with diff fitting is in meters  ' num2str((sum(Rh(smmask(:)).^Lnorme)./sum(smmask(:))).^(1/Lnorme)) '  H  ' num2str((sum(Rv(smmask(:)).^Lnorme)./sum(smmask(:))).^(1/Lnorme)) ' V' ]);
disp(['Standard deviation  ' num2str(std(Rh(:))) '  H  ' num2str(std(Rv(:))) ' V' ]);


%dv1 = pixsize - (dv1);      dh2 = pixsize - (dh2);
% % now we remove the best sphere and keep the stigmatism
% mntoremove1 = ((sum(([dv1(smmask(:));dh2(smmask(:))]).^Lnorme))./(2*sum(smmask(:)))).^(1./Lnorme);
% mntoremove2 = ((sum(([dh1(smmask(:));dv2(smmask(:))]).^Lnorme))./(2*sum(smmask(:)))).^(1./Lnorme);
% 
% dv1 = dv1 - mntoremove1;           dv2 = dv2 - mntoremove2;
% dh1 = dh1 - mntoremove2;           dh2 = dh2 - mntoremove1;
% 
GammaV  = (sum(Rv(smmask(:)).^Lnorme)./sum(smmask(:))).^(1/Lnorme) ./((sum(Rv(smmask(:)).^Lnorme)./sum(smmask(:))).^(1/Lnorme) - distSC./1000);      
GammaH  = (sum(Rh(smmask(:)).^Lnorme)./sum(smmask(:))).^(1/Lnorme) ./((sum(Rh(smmask(:)).^Lnorme)./sum(smmask(:))).^(1/Lnorme) - distSC./1000);

dv1 = (dv1 - mean(dv1(smmask)))./GammaV;
dv2 = (dv2 - mean(dv2(smmask)))./GammaV;
dh1 = (dh1 - mean(dh1(smmask)))./GammaH;
dh2 = (dh2 - mean(dh2(smmask)))./GammaH;
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                integration  to get wavefront gradient                   $
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 

vert  = frankotchellappa(dv2.*smmask,dv1.*smmask);
vert  = vert - mean(vert(smmask(:)));

horiz = frankotchellappa(dh2.*smmask,dh1.*smmask); 
horiz = horiz - mean(horiz(smmask(:)));

% theorically we had to divide by the pixel size to get the magnification
% and then multiply byb the pixel size for the integration
vert  = vert ./(distSC./1000) .*1e-6;      % rad
horiz = horiz./(distSC./1000) .*1e-6;      % rad
% from tehre I reduce, reuse, recycle
ps = cat(3,horiz,vert);
vert2 = vert;       horiz2 = horiz;
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                        integration                                     %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

pixsize = pixsize.* MagnLensToDet;
ps = ps./MagnLensToDet;

mask1 = smmask;     mask2 = smmask;
%calculate gradient error
[p1,p2] = gradient_error(ps(:,:,1),ps(:,:,1),mask1);
[p3,p4] = gradient_error(ps(:,:,2),ps(:,:,2),mask1);
    
% calculate differential focal length
raddiff1 = 1/(mean(mean(diff(p1,1,2)./(pixsize*1e-6))));
raddiff2 = 1/(mean(mean(diff(p4,1,1)./(pixsize*1e-6))));
disp(['Differential focal length with diff fitting is in meters  ' num2str(raddiff1) '  H  ' num2str(raddiff2) ' V ']);
disp(['For a mask of diameter = ' num2str(round(maskDiam)) 'um']);

% calculate a rmse moyenne
dd = ((mean(mean(diff(p1,1,2)))./2 + mean(mean(diff(p4,1,1)))./2 ));
p11 = p1./mean(mean(diff(p1,1,2))).*dd;
p44 = p4./mean(mean(diff(p4,1,1))).*dd;
raddiff11 = 1/(mean(mean(diff(p11,1,2)./(pixsize*1e-6))));
raddiff22 = 1/(mean(mean(diff(p44,1,1)./(pixsize*1e-6))));

%extract wavefront gradient error and put in urad (with astigmatism)

xg = (ps(:,:,1)-p11).*1e6;    xg = xg - mean(xg(mask1));
yg = (ps(:,:,2)-p44).*1e6;    yg = yg - mean(yg(mask1));
% do integration to get wavefront in meter
phi = WftSolveLSChol(yg.*mask1,xg.*mask1,pixsize,mask1).*1e-12;
phi = phi- mean(phi(mask1(:)));         % remove piston

phi = WftSolveLSChol(yg.*mask1,xg.*mask1,1,mask1).*1e-12.*pixsize;
% phi = frankotchellappa(xg.*mask1.*pixsize,yg.*mask1.*pixsize).*1e-12./(2.*pi);
% phi = frankotchellappa(xg.*mask1,yg.*mask1).*1e-12./(2.*pi).*pixsize;

%extract wavefront gradient error and put in urad (without astigmatism and defocus)
xg1 = (ps(:,:,1)-p2 -p1).*1e6;    xg1 = xg1 - mean(xg1(mask1));
yg1 = (ps(:,:,2)-p3 -p4).*1e6;    yg1 = yg1 - mean(yg1(mask1));
phi1 = WftSolveLSChol(yg1.*mask1,xg1.*mask1,pixsize,mask1).*1e-12;
phi1 = phi1- mean(phi1(mask1(:)));      % remove pistonfull map phase
phiFull = WftSolveLSChol(( vert2 - mean( vert2(mask1))).*mask1,(horiz2 - mean(horiz2(mask1))).*mask1,pixsize,ones(size(horiz2))).*1e-12;
phiFull = phiFull- mean(phiFull(mask1(:)));% remove piston

%thickness depends on delta value
thickErr = phi./delta.*1e6;                     % put in microns by the way
thickErr = thickErr - mean(thickErr(mask1(:))); % remove mean
%thickness error without astimatism
thickErr1 = phi1./delta.*1e6;                   % put in microns by the way
thickErr1 = thickErr1 - mean(thickErr1(mask1(:)));% remove mean

output2 = ZernikeCalc(1:15,phi, mask1);
output2 = output2.*1e9;

exportLensFig2D


% % % %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %                              export plots                               %
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



if ~isempty(exportPlots)
    %% export drawings
    dlmwrite(exportFileSummary,['Radius calculated with diff fitting is in meters  ' num2str((sum(Rh(smmask(:)).^Lnorme)./sum(smmask(:))).^(1/Lnorme)) '  H  ' num2str((sum(Rv(smmask(:)).^Lnorme)./sum(smmask(:))).^(1/Lnorme)) ' V' ], '-append','delimiter','');
    dlmwrite(exportFileSummary,['Standard deviation  ' num2str(std2(Rh)) '  H  ' num2str(std2(Rv)) ' V' ], '-append','delimiter','');
 
    print(1,'-dpdf',fullfile(exportPlots,'Wavefront_gradient.pdf'));
    saveas(1, fullfile(exportPlots,'Wavefront_gradient.svg'));
    print(1,'-dpng',fullfile(exportPlots,'Wavefront_gradient.png'));
    
    print(2,'-dpdf',fullfile(exportPlots,'Wavefront_gradient_error.pdf'));
    saveas(2, fullfile(exportPlots,'Wavefront_gradient_error.svg'));
    print(2,'-dpng',fullfile(exportPlots,'Wavefront_gradient_error.png'));

    print(3,'-dpdf',fullfile(exportPlots,'Maks.pdf'));
    saveas(3, fullfile(exportPlots,'Maks.svg'));
    print(3,'-dpng',fullfile(exportPlots,'Maks.png'));
    
    print(4,'-dpdf',fullfile(exportPlots,'Wavefront_error.pdf'));
    saveas(4, fullfile(exportPlots,'Wavefront_error.svg'));
    print(4,'-dpng',fullfile(exportPlots,'Wavefront_error.png'));
    
    %print(5,'-dpdf',fullfile(exportPlots,'Thickness_3D_error.pdf'));
    saveas(5, fullfile(exportPlots,'Wavefront_gradient_error.svg'));
    print(5,'-dpng',fullfile(exportPlots,'Thickness_3D_error.png'));
    
    print(6,'-dpdf',fullfile(exportPlots,'WavefrontError_cuts.pdf'));
    saveas(6, fullfile(exportPlots,'WavefrontError_cuts.svg'));
    print(6,'-dpng',fullfile(exportPlots,'WavefrontError_cuts.png'));
    
    save(fullfile(exportPlots,'phi'),'phi1','phiFull','file1','phiFull')
    
    filecuts = fullfile(exportPlots,'cuts_raw.dat');
    dlmwrite(filecuts, 'Cut lines ','delimiter', '' );
    dlmwrite(filecuts, 'Axis (mm) - Vcut (nm) - Hcut (nm)', '-append','delimiter', '' );
    dlmwrite(filecuts, cutsout, '-append','delimiter', '\t' );
    
    filecuts = fullfile(exportPlots,'cuts.dat');
    dlmwrite(filecuts, 'Cut lines ','delimiter', '' );
    dlmwrite(filecuts, 'Axis (mm) - Vcut (nm) - Hcut (nm)', '-append','delimiter', '' );
    p1 = polyfit(cutsout(:,1),cutsout(:,2),2);      p2 = polyfit(cutsout(:,1),cutsout(:,3),2);
    cutsout(:,2) = cutsout(:,2) -polyval(p1,cutsout(:,1));     cutsout(:,3) = cutsout(:,3) -polyval(p2,cutsout(:,1));
    
    
    figure(100)
    subplot(2,1,2)
    plot(cutsout(:,1),cutsout(:,2),'g')
    subplot(2,1,1)
    plot(cutsout(:,1),cutsout(:,3),'r')
    
    dlmwrite(filecuts, cutsout, '-append','delimiter', '\t' );
    
end;

return;
% % % %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %                               plots                                     %
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % barcolor = [1 0 0].*0.63;
% % 
% % [m1,n1] = size(horiz2);
% % m = (1:1:m1).*pixsize./1000;
% % n = (1:1:n1).*pixsize./1000;
% % 
% % figure(30)
% % subplot(2,2,1)
% % imagesc(n,m,vert2.*1e6 ,[-1 1].*500)
% % set(gca,'DataAspectRatio',[1 1 1]')
% % colormap gray
% % %colormap(flipud(CM1))
% % set(gca,'YTick',0);set(gca,'XTick',0);set(gca,'TickLength',[0 0]);
% % title('Vertical wavefront gradient')
% % t = colorbar('EastOutside','peer',gca);
% % set(get(t,'ylabel'),'String', 'urad','FontName','TimesNewRoman','FontSize',14);
% % scalebar
% % scalebar('Location','southeast','Colour',barcolor,'Bold','True','Unit','mm','ScaleLength',round(n(end))./4)
% % 
% % subplot(2,2,2)
% % imagesc(n,m,horiz2.*1e6 ,[-1 1].*500)
% % set(gca,'DataAspectRatio',[1 1 1]')
% % colormap gray
% % %colormap(flipud(CM1))
% % set(gca,'YTick',0);set(gca,'XTick',0);set(gca,'TickLength',[0 0]);
% % title('Horizontal wavefront gradient')
% % t = colorbar('EastOutside','peer',gca);
% % set(get(t,'ylabel'),'String', 'urad','FontName','TimesNewRoman','FontSize',14);
% % scalebar
% % scalebar('Location','southeast','Colour',barcolor,'Bold','True','Unit','mm','ScaleLength',round(n(end))./4)
% % 
% % subplot(2,2,3)
% % imagesc(n,m,phi5.*1e9.*bigmask)
% % set(gca,'DataAspectRatio',[1 1 1]')
% % colormap gray
% % %colormap(flipud(CM1))
% % set(gca,'YTick',0);set(gca,'XTick',0);set(gca,'TickLength',[0 0]);
% % title('Wavefront')
% % t = colorbar('EastOutside','peer',gca);
% % set(get(t,'ylabel'),'String', 'nm','FontName','TimesNewRoman','FontSize',14);
% % scalebar
% % scalebar('Location','southeast','Colour',barcolor,'Bold','True','Unit','mm','ScaleLength',round(n(end))./4)
% % % xlabel('mm');ylabel('mm')
% % % colorbar
% % phi5 = phiFull - min(phiFull(mask1));
% % phi5(~mask1) = nan;
% % subplot(2,2,4)
% % surf(phi5.*1e9)
% % xlabel('mm');ylabel('mm');zlabel('nm');
% % shading interp
% % title('Wavefront')