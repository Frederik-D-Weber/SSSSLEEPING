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
