%% initialization

%%% add sleeptrip to the path, make sure FieldTrip or related toolboxes
%%% aren't already added
%addpath('D:/sleeptrip')

%%% load all the defaults of SleepTrip and FieldTrip
st_defaults

%%% analyse the ssssleeeping sleep data

%% create the recording and dataset information and design

datanames = {'d-13','d-38'};
excluded = {};

design = {};
datasets = {};
scoringfiles = {};
iRecording = 0;
for iDataname = 1:numel(datanames)
    dataname = datanames{iDataname};
    for iDay = 1:3
        % here we would need to exclude some nights
        %
        %
        %
        datasetname = [dataname '-s-' num2str(iDay)];

        if ~any(strcmp(datasetname,excluded))
            iRecording = iRecording + 1;
            datasets{iDataname,iDay}     = [datasetname '.zip'];
            scoringfiles{iDataname,iDay} = [datasetname '.csv'];
            design = cat(1,design,{iRecording,iDataname,iDay,datasetname});
        end
    end
end

%create a design table and pack it into a dummy result to write it out
design_table = cell2table(design);
design_table.Properties.VariableNames = {'recordingnumber' 'datanamenumber' 'day' 'datasetname'};
design_res = [];
design_res.ori  = 'design';
design_res.type = 'sleep_recordings';
design_res.table = design_table;
% export the design as if it would be a result
cfg = [];
cfg.prefix = 'ssssleeping';
cfg.infix  = 'first_attempt';
cfg.postfix = 'sleep_analysis_design';
filelist_res_design = st_write_res(cfg, design_res);

save('excluded', 'excluded')
save('datasets', 'datasets')
save('scoringfiles', 'scoringfiles')
save('design', 'design')
save('design_table', 'design_table')
save('design_res', 'design_res')




%% create the recording information
load('datasets')
eegchannels = {{'EEG L', 'EEG R'}, {'EEG L', 'EEG R'}, {'EEG L', 'EEG R'}, ... 
               {'EEG L', 'EEG R'}, {'EEG L', 'EEG R'}, {'EEG L', 'EEG R'}};
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
        recording.eegchannels        = eegchannels{iDataset};
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
    cfg.postfix = recording.name;
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
cfg.postfix = 'all_recordings';
filelist_res_sleepdescriptives = st_write_res(cfg, res_sleepdescriptives_appended); 


%% plot the hypnograms, do not display the unknown sleep epochs
load('recordings');
load('scorings');
for iRecording = 1:numel(recordings)
    recording = recordings{iRecording};
    scoring = scorings{iRecording}; 
    cfg = [];
    cfg.plotunknown        = 'no'; 
    cfg.plotexcluded       = 'no';
    cfg.figureoutputfile   = [recording.name '.pdf'];
    cfg.figureoutputformat = 'pdf';
    cfg.sleeponsetdef      = 'AASM';
    figure_handle = st_hypnoplot(cfg, scoring);
    close(figure_handle)
end

%% caluculate the power and energy (density) in non-REM and REM sleep
load('recordings');
load('scorings');
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
    cfg.postfix = strjoin(stages{iStages},'_');
    filelist_res_power_bins = st_write_res(cfg, res_power_bins{iStages,:});
    filelist_res_power_bands = st_write_res(cfg, res_power_bands{iStages,:});
end

save('stages', 'stages')
save('res_power_bins', 'res_power_bins');
save('res_power_bands', 'res_power_bands');



%% find the frequency power peaks, only one, e.g. for the 'fast spindles'
load('res_power_bins')
load('recordings')
load('design_table')



dataids = unique(design_table.datanamenumber)';
spindle_freqpeaks_per_dataid = {};
res_spindle_freqpeaks = {};

%iterate over all subjects by using the data id from the design matrix
for iDataid = dataids
    iRecordings = design_table.recordingnumber((design_table.datanamenumber == iDataid));
    %all non-REM recordings
    [res_power_bins_appended_dataname] = st_append_res(res_power_bins{1,iRecordings});
    
    cfg = [];
    cfg.peaknum = 1;
    [res_freqpeaks] = st_freqpeak(cfg,res_power_bins_appended_dataname);
    res_freqpeaks.table.freqpeak1((res_freqpeaks.table.freqpeak1 < 9) | (res_freqpeaks.table.freqpeak1 > 16)) = NaN;
    spindle_freqpeaks_per_dataid{iDataid} = res_freqpeaks.table.freqpeak1;
    res_spindle_freqpeaks{iDataid} = res_freqpeaks;
end

[res_spindle_freqpeaks_appended] = st_append_res(res_spindle_freqpeaks{:});

% export the design as if it would be a result
cfg = [];
cfg.prefix = 'ssssleeping';
cfg.infix  = 'first_attempt';
cfg.postfix = 'spindle_freqpeaks';
filelist_res_design = st_write_res(cfg, res_spindle_freqpeaks_appended);
   
%keep the frequency peaks for later
save('spindle_freqpeaks_per_dataid', 'spindle_freqpeaks_per_dataid');
save('res_spindle_freqpeaks_appended', 'res_spindle_freqpeaks_appended');

%% detect spindle on the frequency power peaks
load('recordings')
load('scorings')
load('res_spindle_freqpeaks_appended')

res_spindles_channels = cell(1,numel(recordings));
res_spindles_events = cell(1,numel(recordings));

for iRecording = 1:numel(recordings)
    recording = recordings{iRecording};
    cfg = [];
    cfg.scoring          = scorings{iRecording};
    cfg.stages           = {'N2', 'N3'}; % {'R'};
    cfg.channel          = recording.eegchannels;
    cfg.minamplitude     = 5;
    cfg.maxamplitude     = 50; %for a frontal channel
    freqpeak = res_spindle_freqpeaks_appended.table.freqpeak1(iRecording);
    resnum = res_spindle_freqpeaks_appended.table.resnum(iRecording);
    
    %no freqpeak, take the subject mean
    if isnan(freqpeak)
        freqpeak = mean(res_spindle_freqpeaks_appended.table.freqpeak1(res_spindle_freqpeaks_appended.table.resnum == resnum));
    end
    
    %no freqpeak, take the group mean
    if isnan(freqpeak)
        freqpeak = nanmean(res_spindle_freqpeaks_appended.table.freqpeak1(:));
    end
    
    cfg.centerfrequency  = freqpeak;
    
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
cfg.infix  = 'first_attempt';
cfg.postfix = 'spindles_by_freqpeaks';
filelist_res_spindles_appended = st_write_res(cfg, res_spindles_channels_appended, res_spindles_events_appended);


%% plot spindles on a hypnogram per subject and save as pdf
load('recordings')
load('scorings')
load('res_spindles_events')
for iRecording = 1:numel(recordings)
    recording = recordings{iRecording};

    res_event = res_spindles_events{iRecording};
    event_abbrev = 'spd';
    
    scoring = scorings{iRecording};
    
    % also plot event properties like amplitude and frequency for each event
    cfg = [];
    cfg.plotunknown        = 'no'; 
    cfg.plotexcluded       = 'no';
    cfg.figureoutputfile   = [recording.name '_events_' event_abbrev '.pdf'];
    cfg.figureoutputformat = 'pdf';
    
    % init the the event structures to fill them by channel availability
    cfg.eventtimes  = {};
    cfg.eventvalues = {};
    cfg.eventranges = {};
    cfg.eventlabels = {};
    
    for iCh = 1:numel(recording.eegchannels)
        ch = recording.eegchannels{iCh};
        
        % the trough with the larges amplitude of the spindle shall give its time
        % point, this is important for time-locked event related potentials
        event_troughs_ch = res_event.table.seconds_trough_max(strcmp(res_spindles_event.table.channel,{ch}));

        % we can also get the amplitudes
        event_amplitude_ch = res_event.table.amplitude_peak2trough_max(strcmp(res_spindles_event.table.channel,{ch}));
    
        % ... or the frequency of each sleep spindle
        event_frequency_ch = res_event.table.frequency_by_mean_pk_trgh_cnt_per_dur(strcmp(res_spindles_event.table.channel,{ch}));
    
        cfg.eventtimes  = cat(1,cfg.eventtimes,{event_troughs_ch'; ...
                                                event_troughs_ch'});
        cfg.eventvalues  = cat(1,cfg.eventvalues,{event_amplitude_ch'; ...
                                                  event_frequency_ch'});
        cfg.eventranges  = cat(1,cfg.eventranges,{[min(event_amplitude_ch), max(event_amplitude_ch)]; ...
                                                  [min(event_frequency_ch), max(event_frequency_ch)]});
        cfg.eventlabels  = cat(1,cfg.eventlabels,{[[event_abbrev ' '] 'ampl ' ch]; [[event_abbrev ' '] 'freq ' ch]});

    end
   
    figure_handle = st_hypnoplot(cfg, scoring);
    close(figure_handle);
end

%% data preprocessing
load('recordings');
for iRecording = 1:numel(recordings)
    recording = recordings{iRecording};
    
    cfg = [];
    cfg.dataset    = recording.dataset;
    cfg.continuous = 'yes';
    %cfg.channel    = 'all';
    cfg.channel    = recording.eegchannels;
    %cfg.montage    = recording.montage;
    cfg.lpfilter   = 'yes';
    cfg.lpfreq     = 35;
    cfg.hpfilter   = 'yes';
    cfg.hpfreq     = 0.1;
    cfg.hpfilttype = 'but';
    cfg.hpfiltord  = 4;
    data = st_preprocessing(cfg);
    
    %resample to lower sampling rate
    cfg = [];
    cfg.detrend = 'no';
    cfg.resamplefs = 100;
    data = ft_resampledata(cfg,data);
    
    save(['data-' num2str(iRecording)], 'data');
end
    

%% ERP and ERFs
load('recordings');

wavelet_length = 4;

pre_trial_seconds = 3;
post_trial_seconds = 3;
padding_buffer_seconds = wavelet_length*(1/freq_min)+1;

freq_min = 0.5;
freq_max = 20;
freq_steps = 0.5;
freq_time_steps = (pre_trial_seconds+post_trial_seconds)/(freq_max/freq_steps);




save('padding_buffer_seconds', 'padding_buffer_seconds')
save('pre_trial_seconds', 'pre_trial_seconds')
save('post_trial_seconds', 'post_trial_seconds')
save('freq_steps', 'freq_steps')
save('freq_time_steps', 'freq_time_steps')

timelocks = {};
erfs = {};

for iRecording = 1:numel(recordings)
    recording = recordings{iRecording};
    
    load(['data-' num2str(iRecording)]);
    
    %Event
    
    res_event = res_spindles_events{iRecording};
    event_abbrev = 'spd';
    
    for iCh = 1:numel(recording.eegchannels)
        ch = recording.eegchannels{iCh};
        
        %events in one channel
        eventsSeconds = res_event.table.seconds_trough_max(strcmp(res_event.table.channel,{ch}));
        
        %select only the one channel analysed
        cfg = [];
        cfg.channel = ch;
        %cfg.latency = [60*60*1 60*60*2];
        data_ch = ft_selectdata(cfg, data);
        
        % ERP
        event_samples = eventsSeconds*data.fsample;
        event_label = event_abbrev;
        
        padding_buffer_samples = padding_buffer_seconds*data.fsample;
        pre_trial_samples = pre_trial_seconds*data.fsample;
        post_trial_samples = post_trial_seconds*data.fsample;
        
        cfg     = [];
        begsamples = event_samples-pre_trial_samples-padding_buffer_samples;
        endsamples = event_samples+post_trial_samples+padding_buffer_samples;
        offsets = repmat(-(pre_trial_samples+padding_buffer_samples),numel(event_samples),1);
        trl = [begsamples, endsamples, offsets];
        
        % make sure the trial is using samples
        trl = round(trl);
        
        % remove trials that overlap with the beginning of the file
        sel = trl(:,1)>1;
        trl = trl(sel,:);
        
        % remove trials that overlap with the end of the file
        datalengthsamples = size(data.trial{1},2);
        sel = trl(:,2)<datalengthsamples;
        trl = trl(sel,:);
        
        ntrials = size(trl,1);
        
        cfg.trl = trl;
        data_events = ft_redefinetrial(cfg, data_ch);
        
        save(['data_events-' event_abbrev '-' ch '-' num2str(iRecording)], 'data_events');

        %average signal timelocked to the trough.
        cfg        = [];
        [timelock] = ft_timelockanalysis(cfg, data_events);
        
        cfg = [];
        cfg.latency = [-pre_trial_seconds post_trial_seconds];
        timelock = ft_selectdata(cfg,timelock);
        
        timelock.ntrials = ntrials;
        timelock.event_label = event_label;
        timelocks{iRecording,iCh} = timelock;
        timelock = []; % in case the dataset does not fit in memory well.
        
        
        %ERF
        cfg               = [];
        cfg.channel       = 'all';
        cfg.method        = 'wavelet';
        cfg.length        = wavelet_length;
        cfg.foi           = freq_min:freq_steps:freq_max; 
        cfg.toi           = [(-padding_buffer_seconds-pre_trial_seconds):freq_time_steps:(post_trial_seconds+padding_buffer_seconds)]; % 0.1 s steps
        %cfg.keeptrials    = 'yes';
        data_freq = ft_freqanalysis(cfg, data_events);
        
        
        cfg = [];
        cfg.latency = [-pre_trial_seconds post_trial_seconds];
        data_freq = ft_selectdata(cfg,data_freq);
        
        data_freq.ntrials = ntrials;
        data_freq.event_label = event_label;
        erfs{iRecording,iCh} = data_freq;
        
        data_ch = []; % in case the dataset does not fit in memory well.
        data_events = []; % in case the dataset does not fit in memory well.
        data_freq = []; % in case the dataset does not fit in memory well.
        
    end
    data = []; % in case the dataset does not fit in memory well.
end


save('timelocks', 'timelocks');
save('erfs', 'erfs');

%% plot ERPs
load('recordings')
load('timelocks');
% addpath('D:\sleeptrip\compat\matlablt2016b')
set(0, 'DefaultFigureRenderer', 'painters');

time_min = -1.5;
time_max = 1.5;
time_ticks = time_min:0.25:time_max;
time_tickLabels = arrayfun(@(t) num2str(t), time_ticks(:), 'UniformOutput', false)';
time_tickLabels{time_ticks == 0} = 'Trough';
time_tickLabels(2:2:(end-1)) = {' '};

for iRecording = 1:numel(recordings)
    recording = recordings{iRecording};
    for iCh = 1:numel(recording.eegchannels)
        ch = recording.eegchannels{iCh};
        
        timelock = timelocks{iRecording,iCh};
        
        event_label = timelock.event_label;
        timelock = rmfield(timelock, 'event_label');
        ntrials = timelock.ntrials;
        timelock = rmfield(timelock, 'ntrials');

        %ch = timelock.label{1};
        fh = figure;
        cfg           = [];
        cfg.xlim      = [time_min time_max];
        cfg.linewidth = 2;
        %cfg.parameter = 'avg'; % this should be mentioned, otherwise the function might be confused and gives errors
        cfg.title = ['ERP time-locked to trough of ' event_label ' at ' ch ' n = ' num2str(ntrials)];
        ft_singleplotER(cfg,timelock)
        
        fontsize = 0.2;
        axh = gca;
        %fh = gcf;
        
        
        set(fh, 'color',[1 1 1]);
        set(axh,'FontUnits','inches')
        set(axh,'Fontsize',fontsize);
        
        ylabel(axh,'Signal [µV]');
        xlabel(axh,'Time [s]');
        set(axh, 'xTick', time_ticks);
        set(axh, 'xTickLabel', time_tickLabels);
        %set(axh, 'xMinorTick', 'on');
        set(axh, 'TickDir','out');
        set(axh, 'box', 'off')
        set(axh, 'LineWidth',2)
        set(axh, 'TickLength',[0.02 0.02]);
        
        figure_width = 10;     % Width in inches
        figure_height = 6;    % Height in inches
        
        pos = get(fh, 'Position');
        set(fh, 'Position', [pos(1) pos(2) figure_width*100, figure_height*100]); %<- Set size
        
        % Here we preserve the size of the image when we save it.
        set(fh,'InvertHardcopy','on');
        set(fh,'PaperUnits', 'inches');
        papersize = get(fh, 'PaperSize');
        left = (papersize(1)- figure_width)/2;
        bottom = (papersize(2)- figure_height)/2;
        myfiguresize = [left, bottom, figure_width, figure_height];
        set(fh,'PaperPosition', myfiguresize);
        set(fh,'PaperOrientation', 'portrait');
        
        saveas(fh, [recording.name '_ERP_' event_label '_' ch '.fig']);
        print(fh,['-d' 'epsc'],['-r' '300'],[recording.name '_ERP_' event_label '_' ch '.eps']);
        print(fh,['-d' 'pdf'],['-r' '300'],[recording.name '_ERP_' event_label '_' ch '.pdf']);
        
        close(fh);
        
    end
end



%% plot ERFs
load('recordings')
load('erfs');
% addpath('D:\sleeptrip\compat\matlablt2016b')
set(0, 'DefaultFigureRenderer', 'painters');

time_min = -1.5;
time_max = 1.5;
time_ticks = time_min:0.25:time_max;
time_tickLabels = arrayfun(@(t) num2str(t), time_ticks(:), 'UniformOutput', false)';
time_tickLabels{time_ticks == 0} = 'Trough';
time_tickLabels(2:2:(end-1)) = {' '};

for iRecording = 1:numel(recordings)
    recording = recordings{iRecording};
    for iCh = 1:numel(recording.eegchannels)
        ch = recording.eegchannels{iCh};
        
        data_freq = erfs{iRecording,iCh};
        
        event_label = data_freq.event_label;
        timelock = rmfield(data_freq, 'event_label');
        ntrials = data_freq.ntrials;
        timelock = rmfield(data_freq, 'ntrials');

        %ch = timelock.label{1};
        fh = figure;
        cfg           = [];
        cfg.xlim      = [time_min time_max];
        cfg.linewidth = 2;
        cfg.title = ['ERF time-locked to trough of ' event_label ' at ' ch ' n = ' num2str(ntrials)];
        ft_singleplotTFR(cfg,data_freq)
        
        fontsize = 0.2;
        axh = gca;
        %fh = gcf;
        
        
        set(fh, 'color',[1 1 1]);
        set(axh,'FontUnits','inches')
        set(axh,'Fontsize',fontsize);
        
        ylabel(axh,'Frequency [Hz]');
        xlabel(axh,'Time [s]');
        set(axh, 'xTick', time_ticks);
        set(axh, 'xTickLabel', time_tickLabels);
        %set(axh, 'xMinorTick', 'on');
        set(axh, 'TickDir','out');
        set(axh, 'box', 'off')
        set(axh, 'LineWidth',2)
        set(axh, 'TickLength',[0.02 0.02]);
        
        figure_width = 10;     % Width in inches
        figure_height = 6;    % Height in inches
        
        pos = get(fh, 'Position');
        set(fh, 'Position', [pos(1) pos(2) figure_width*100, figure_height*100]); %<- Set size
        
        % Here we preserve the size of the image when we save it.
        set(fh,'InvertHardcopy','on');
        set(fh,'PaperUnits', 'inches');
        papersize = get(fh, 'PaperSize');
        left = (papersize(1)- figure_width)/2;
        bottom = (papersize(2)- figure_height)/2;
        myfiguresize = [left, bottom, figure_width, figure_height];
        set(fh,'PaperPosition', myfiguresize);
        set(fh,'PaperOrientation', 'portrait');
        
        saveas(fh, [recording.name '_ERP_' event_label '_' ch '.fig']);
        print(fh,['-d' 'epsc'],['-r' '300'],[recording.name '_ERP_' event_label '_' ch '.eps']);
        print(fh,['-d' 'pdf'],['-r' '300'],[recording.name '_ERP_' event_label '_' ch '.pdf']);
        
        close(fh);
        
    end
end





