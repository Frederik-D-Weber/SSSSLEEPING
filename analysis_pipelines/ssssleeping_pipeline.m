%% initialization

%%% add sleeptrip to the path, make sure FieldTrip or related toolboxes
%%% aren't already added
%addpath('D:/sleeptrip')

%%% load all the defaults of SleepTrip and FieldTrip
st_defaults

%% analyse our ssssleeeping sleep data

datanames = {'d-13','d-38'};

datasets = {};
scoringfiles = {};
for iDataname = 1:numel(datanames)
    dataname = datanames{iDataname};
    for iNight = 1:3
        % here we would need to exclude some nights
        %
        %
        %
        datasets{iDataname,iNight}     = [dataname '-s-' num2str(iNight) '.zip'];
        scoringfiles{iDataname,iNight} = [dataname '-s-' num2str(iNight) '.csv'];
    end
end

% create some subjects

nDatasets = numel(datasets);
recordings = cell(1,nDatasets);

for iDataset = 1:nDatasets
        recording = [];
        % take the numer as subject name
        recording.name               = datasets{iDataset};
        recording.dataset            = datasets{iDataset};
        recording.scoringfile        = scoringfiles{iDataset};

        %these things are the same in all subjects
        recording.lightsoff          = 0;
        recording.scoringformat      = 'zmax'; % e.g. 'zmax' or 'spisop'
        recording.standard           = 'aasm'; % 'aasm' or 'rk'
        recording.scoring_dataoffset = 0;
        recording.eegchannels        = {'EEG L', 'EEG R'};
        recording.noisechannels        = {'NOISE'};
        recording.orientationchannels  = {'dX','dY','dZ'};

        %save subject individually
        save(['recording-' num2str(iDataset)],'recording');
        recordings{iDataset} = recording;
end
%save all the subjects in a cell array
save('recordings','recordings');

%% read in the sleep scorings
scorings = cell(1,numel(recordings));
for iRecording = 1:numel(recordings)
    recording = recordings{iRecording};
    
    % read scoring
    cfg = [];
    cfg.scoringfile   = recording.scoringfile;
    cfg.scoringformat = recording.scoringformat;
    cfg.standard      = recording.standard; % 'aasm' or 'rk'
    [scoring] = st_read_scoring(cfg);
    scoring.lightsoff = recording.lightsoff;

    scorings{iRecording} = scoring;
end
save('scorings', 'scorings');


%% plot the hypnograms
%load('scorings');
for iRecording = 1:numel(recordings)
    recording = recordings{iRecording};
    scoring = scorings{iRecording}; 
% also plot event properties like amplitude and frequency for each event
    cfg = [];
    cfg.plotunknown        = 'no'; 
    cfg.figureoutputfile   = [recording.name '.pdf'];
    cfg.figureoutputformat = 'pdf';
    figure_handle = st_hypnoplot(cfg, scoring);
end





%% caluculate the power
stages = {{'N2', 'N3'},{'R'}};

res_power_bins = {};
res_power_bands = {};

for iStages = 1:numel(stages)
    for iRecording = 1:numel(recordings)
        
        recording = recordings{iRecording};
        recording.name
        % non-rem power in the first sleep cycle
        cfg = [];
        cfg.scoring     = scorings{iRecording};
        cfg.stages      = stages{iStages}; % {'R'};
        cfg.channel     = recording.eegchannels;
        cfg.dataset     = recording.dataset;
        cfg.foilim      = [0.5 30];
        cfg.bands       = ...
            {{'SWA', 0.5, 4},...
            {'spindle', 10, 14}};
        [res_power_bin, res_power_band] = st_power(cfg);

        res_power_bins{iStages, iRecording} = res_power_bin;
        res_power_bands{iStages, iRecording} = res_power_band;
    end
end

for iStages = 1:numel(stages)
    cfg = [];
    cfg.prefix = 'ssssleeping';
    cfg.infix  = 'first_attempt';
    cfg.posfix = strjoin(stages{iStages},'_');
    filelist_res_power = st_write_res(cfg, res_power_bins{iStages,:}, res_power_bands{iStages,:});
end

% put the results together and write them out
% [res_power_bins_appended] = st_append_res(res_power_bins{:});
% [res_power_bands_appended] = st_append_res(res_power_bands{:});


%% find the frequency power peaks, only one, e.g. for the 'fast spindles'
cfg = [];
cfg.peaknum = 1;
[res_power_bins_appended_dataname_1] = st_append_res(res_power_bins{1,1:3});
[res_power_bins_appended_dataname_2] = st_append_res(res_power_bins{1,4:6});

[freqpeaks1_dataname_1, dummy] = st_freqpeak(cfg,res_power_bins_appended_dataname_1);
[freqpeaks1_dataname_2, dummy] = st_freqpeak(cfg,res_power_bins_appended_dataname_2);
