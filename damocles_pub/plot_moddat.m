s=0.9;
lim=0.8;
limy=6;
doublet=1;
sm=3;
sf=1e13;

str='day 714';
add=0;

if (add==1) 
    
load 'd714_OI_ext.txt';
fluxext=d714_OI_ext(:,2);
velext=d714_OI_ext(:,1);
end

importdata('line.out',' ',1);
line_out=ans.data;
clearvars ans
importdata('line.in',' ',2);
line_in=ans.data;
clearvars ans
importdata('output/output.out',' ',1);
output=ans.data;
clearvars ans

fluxdat=line_in(:,2);

if doublet==1
    fluxmod=output(:,2);
    vel=3e5*(output(:,1)-630.0)./630.0;
else
    fluxmod=output(:,3);
    vel=output(:,2);
end

fluxdat(fluxdat==0)=nan;

if (add==1)
fluxdat=cat(1,fluxdat,fluxext);

veldat=cat(1,line_in(:,1),velext);
end
fluxdat=fluxdat-0.0e-13;%-nanmin(fluxdat)%-0.05e-15;
fluxmod=fluxmod*s*(nanmax(fluxdat))/nanmax(fluxmod);

fluxmod=smooth(fluxmod,sm);
fluxdat=smooth(fluxdat,1);

box on;

if add==1
    plot(veldat*1e-4,fluxdat*sf,vel*1e-4,fluxmod*sf,'linewidth',1.25);
else
    plot(line_in(:,1)*1e-4,fluxdat*sf,vel*1e-4,fluxmod*sf,'linewidth',1.25);
end 



ylim([0 limy]);
xlim([-lim lim]);
leg=legend('observed','model');
leg.FontSize=13;
%legend boxoff
xlabel('velocity (10$^{4}$ km s$ ^{-1}$)','Interpreter','LaTex','FontSize',14);
ylabel('flux ($10^{-15}$ ergs cm$^{-2}$ s$^{-1}$ \AA $^{-1}$)','Interpreter','LaTex','FontSize',14);
h=annotation('textbox');
h.FontSize=13;
h.LineStyle='none';
h.Position=[0.15 0.83 0.2 0.07];
h.String=str;
line([0,0],ylim,'Color','black','LineWidth',0.01,'LineStyle',':');

