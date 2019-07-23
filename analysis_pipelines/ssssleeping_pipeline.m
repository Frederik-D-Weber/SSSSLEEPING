
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
load('recordings')
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

    save(['scoring-' num2str(iRecording)],'scoring');

    scorings{iRecording} = scoring;
end
save('scorings', 'scorings');

%% calcualte sleep descriptives from scoring
load('scorings')
load('recordings')

res_sleepdescriptives = cell(1,numel(recordings));
for iRecording = 1:numel(recordings)
    scoring = scorings{iRecording};
    recording = recordings{iRecording};
    
    cfg = [];
    res_sleepdescriptive = st_scoringdescriptives(cfg, scoring);
    
    % export the result
    cfg = [];
    cfg.prefix = 'ssssleeping';
    cfg.infix  = 'first_attempt';
    cfg.posfix = recording.name;
    filelist_res_sleepdescriptives = st_write_res(cfg, res_sleepdescriptive); 
        
    res_sleepdescriptives{iRecording} = res_sleepdescriptive;
end
save('res_sleepdescriptives', 'res_sleepdescriptives');

%concatenate the results
[res_sleepdescriptives_appended] = st_append_res(res_sleepdescriptives{:});

%res_sleepdescriptives_appended.table

% export the results of all recordings
cfg = [];
cfg.prefix = 'ssssleeping';
cfg.infix  = 'first_attempt';
cfg.posfix = 'all_recordings';
filelist_res_sleepdescriptives = st_write_res(cfg, res_sleepdescriptives_appended); 


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
    cfg.sleeponsetdef      = 'AASM';
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
    filelist_res_power_bins = st_write_res(cfg, res_power_bins{iStages,:});
    filelist_res_power_bands = st_write_res(cfg, res_power_bands{iStages,:});
end

% put the results together and write them out
% [res_power_bins_appended] = st_append_res(res_power_bins{:});
% [res_power_bands_appended] = st_append_res(res_power_bands{:});

save('res_power_bins', 'res_power_bins');
save('res_power_bands', 'res_power_bands');


%% find the frequency power peaks, only one, e.g. for the 'fast spindles'
load('res_power_bins')
cfg = [];
cfg.peaknum = 1;
[res_power_bins_appended_dataname_1] = st_append_res(res_power_bins{1,1:3});
[res_power_bins_appended_dataname_2] = st_append_res(res_power_bins{1,4:6});

[freqpeaks1_dataname_1, dummy] = st_freqpeak(cfg,res_power_bins_appended_dataname_1);
[freqpeaks1_dataname_2, dummy] = st_freqpeak(cfg,res_power_bins_appended_dataname_2);

%keep the results for later
save('spindle_power_peak_freqs', 'freqpeaks1');

%% detect spindle on the frequency power peaks
load('recordings')
load('scorings')
load('spindle_power_peak_freqs')

res_spindles_channels = cell(1,numel(recordings));
res_spindles_events = cell(1,numel(recordings));

for iRecording = 1:numel(recordings)
    recording = recordings{iRecording};
    cfg = [];
    cfg.scoring          = scorings{iRecording};
    cfg.stages           = {'N2', 'N3'}; % {'R'};
    cfg.channel          = recording.eegchannels;
    cfg.centerfrequency  = freqpeaks1(iRecording);
    cfg.dataset          = recording.dataset;
    [res_spindles_channel, res_spindles_event, res_spindles_filter] = st_spindles(cfg);
    
    res_spindles_channels{iRecording} = res_spindles_channel;
    res_spindles_events{iRecording} = res_spindles_event;
end

save('res_spindles_channels', 'res_spindles_channels')
save('res_spindles_events', 'res_spindles_events')

% put the results together and write them out
[res_spindles_channels_appended] = st_append_res(res_spindles_channels{:});
[res_spindles_events_appended] = st_append_res(res_spindles_events{:});
cfg = [];
cfg.prefix = 'ssssleeping';
cfg.infix  = recording.name;
cfg.posfix = '';
filelist_res_spindles_appended = st_write_res(cfg, res_spindles_channels_appended, res_spindles_events_appended);


%% plot spindles on a hypnogram per subject and save as pdf
load('recordings')
load('res_spindles_events')
for iRecording = 1:numel(recordings)
    recording = recordings{iRecording};

    res_spindles_event = res_spindles_events{iRecording};
    
    ch1 = recording.eegchannels{1};
    ch2 = recording.eegchannels{2};
    scoring = scorings{iRecording};
    
    % the trough with the larges amplitude of the spindle shall give its time
    % point, this is important for time-locked event related potentials
    spindle_troughs_ch1 = res_spindles_event.table.seconds_trough_max(strcmp(res_spindles_event.table.channel,{ch1}));
    spindle_troughs_ch2 = res_spindles_event.table.seconds_trough_max(strcmp(res_spindles_event.table.channel,{ch2}));


    % we can also get the amplitudes
    spindle_amplitude_ch1 = res_spindles_event.table.amplitude_peak2trough_max(strcmp(res_spindles_event.table.channel,{ch1}));
    spindle_amplitude_ch2 = res_spindles_event.table.amplitude_peak2trough_max(strcmp(res_spindles_event.table.channel,{ch2}));

    % ... or the frequency of each sleep spindle
    spindle_frequency_ch1 = res_spindles_event.table.frequency_by_mean_pk_trgh_cnt_per_dur(strcmp(res_spindles_event.table.channel,{ch1}));
    spindle_frequency_ch2 = res_spindles_event.table.frequency_by_mean_pk_trgh_cnt_per_dur(strcmp(res_spindles_event.table.channel,{ch2}));

    % also plot event properties like amplitude and frequency for each event
    cfg = [];
    cfg.plotunknown        = 'no'; 
    cfg.figureoutputfile   = [recording.name '_events_spindles' '.pdf'];
    cfg.figureoutputformat = 'pdf';
    cfg.eventtimes  = {spindle_troughs_ch1';...
                       spindle_troughs_ch2';...
                       spindle_troughs_ch1';...
                       spindle_troughs_ch2'};
    cfg.eventvalues = {spindle_amplitude_ch1';...
                       spindle_amplitude_ch2';...
                       spindle_frequency_ch1';...
                       spindle_frequency_ch2'};
    cfg.eventranges = {[min(spindle_amplitude_ch1), max(spindle_amplitude_ch1)];...
                       [min(spindle_amplitude_ch2), max(spindle_amplitude_ch2)];...
                       [min(spindle_frequency_ch1), max(spindle_frequency_ch1)];...
                       [min(spindle_frequency_ch2), max(spindle_frequency_ch2)]};
    cfg.eventlabels = {['spd ' 'ampl ' ch1], ['spd ' 'ampl ' ch2], ...
                       ['spd ' 'freq ' ch1], ['spd ' 'freq ' ch2]};
    figure_handle = st_hypnoplot(cfg, scoring);
end
