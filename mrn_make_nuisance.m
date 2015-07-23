function [R dat_qual]=mrn_make_nuisance(sess_im,motion_file,save_dir)
%mrn_make_nuisance makes 24 motion regressors and spike indicator functions
%for mb mrn pipelined data
%   [R dat_qual]=mrn_make_nuisance(sess_im,motion_file,save_dir)
%       give this function
%   sess_im   the session images you want to run spike id on
%   motion    the 6 motion regressor text file
%   designed to run in bash with the mrn_to_canlab script marianne put together
%   designed to run on preprocessed multiband data with mrn pipeline
%   by marianne 2015

% move to the canlab subject folder appropriate place
curr_dir=pwd;
cd(save_dir)
outfilename = 'noise_model_1';
outdirname = 'spm_modeling';
dout = fullfile(save_dir,outdirname);
if ~exist(dout,'dir'), mkdir(dout); end

S=sess_im;M=motion_file;
% load canlab respos - necessary?
% addpath(genpath('/work/ics/data/projects/wagerlab/Repository'));
% addpath(genpath('spm8')) % addpath to spm?

[g,spikes,gtrim,nuisance_covs,snr]=scn_session_spike_id(S);
%suppress figures but save them?

nuisance_covs(:,1)=[];
R{1}=[zeros(1,size(nuisance_covs,2)); nuisance_covs];
 
% % remove duplicate spikes
spikes=R{1};
uniquespikes = diag(any(spikes,2));
uniquespikes = uniquespikes(:,any(uniquespikes)); %didnt work
        
% save other data qual info somewhere
dat_qual.g=g;
dat_qual.spikes=spikes;
dat_qual.gtrim=gtrim;
dat_qual.snr=snr;

save Nuisance_covariates_R R
save QualInfo dat_qual

% read in motion text file properly
Motion=importdata(M);
if size(Motion,2) ~= 6
    error('Motion 1D file is missing some regressors')
else
    Mz=zscore(Motion);
    smpd=[0 0 0 0 0 0;diff(Mz)];
    Mot=[Mz Mz.^2 smpd smpd.^2];
end
R{2}=Mot;
if length(R{2}) ~= length(R{1})
    error('Motion regressors and spike id are not the same size')
end

temp=[R{2} uniquespikes];
clear R;
R=temp;
% save these there
save noise_model_1.mat R

% move back
cd(curr_dir);

end
