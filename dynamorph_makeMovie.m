% dynamorph_makeMovie.m
%
% script to morph movie faces
%
% last modified 8-21-16
% apj

% assign projects directory
PROJ_DIR                        = fullfile('/home','lab','Cloud2','movies','human');
FACE_DIR                        = fullfile(PROJ_DIR,'faces','fin_frames');
VOICE_DIR                       = fullfile(PROJ_DIR,'voices','voice_overs','syllable','voice_stim');
STRAIGHT_DIR                    = fullfile(PROJ_DIR,'voices','voice_overs','syllable');
STIMOUT_DIR                     = fullfile(PROJ_DIR,'dynamic');

SCALE                           = 1;
CONDITIONS                      = {'audVid';'audOnly';'visOnly'};
TRAJ_DIRECTION_LIST             = {'rad','tan'};
N_IDENT                         = 8; % define numbers of identities (face/voice combinations)
PRS                             = 125;
MOV_FTYPE                       = '.avi';
% FRAME_RATE                      = 30;

% % create figure
% figure

% load order of voices from .csv files
FID                             = fopen(fullfile(PROJ_DIR,'turk','results','proj2','reordered_nameList.csv'));
M                               = textscan(FID, '%s', 'Delimiter',','); % you will need to change the number   of values to match your file %f for numbers and %s for strings.
FACE_ORDER                      = M{:};
fclose(FID);

% load order of voices from .csv files
FID                             = fopen(fullfile(STRAIGHT_DIR,'reordered_nameList.csv'));
M                               = textscan(FID, '%s', 'Delimiter',','); % you will need to change the number   of values to match your file %f for numbers and %s for strings.
M                               = M{:};
M                               = M(cellfun(@isempty,strfind(M,'voiceAve')));
fclose(FID);
SPAM                            = regexp(M,'\d+(\.)?','match');
VOICE_ORDER                     = nan(size(FACE_ORDER));
for i = 1:length(SPAM)
    FOO                         = SPAM{i};
    VOICE_ORDER(i)              = str2double(FOO{1});
end

% stagger voices to match with faces optimally
STEPS_STAGGERED                 = 0;
VOICE_ORDER                     = circshift(VOICE_ORDER,[STEPS_STAGGERED,0]);

% display table
disp(table(FACE_ORDER,VOICE_ORDER,'RowNames',cellfun(@num2str,num2cell(1:8),'un',0)))

MORPH_LEVELS                    = [100 75 50 25]; % define morph steps
NOISE_TITLE                     = {[];'_noisy'};
TOT_N_FRAME                     = 601; % define numbers of frames
IM_DIMS                         = size(imresize(imread(fullfile(FACE_DIR,...
    'Ave','Average_001RGB.tiff')),SCALE)); % define frame size
FRAME_LIST                      = 202+[1:2:15 13:-2:1]; % define which frames we include
FULLSCR                         = get(0,'ScreenSize'); % get screen size
aud_max                         = [];
aud_min                         = [];

% step through each noise condition (off and on)
for NOISE_COND = 1:2
    
    % step through each exp. condition
    for cond = 1:length(CONDITIONS)
        
        % step through each trajectory direction (rad and tan)
        for D = 1:length(TRAJ_DIRECTION_LIST)
            
            % step through each face identity
            for i = 1:N_IDENT
                
                disp(['Creating ' upper(TRAJ_DIRECTION_LIST{D}) ' morph clips for face#: ' num2str(i)])
                
                % avoid saving 100% tan morph
                if D==1
                    START           = 1;
                else
                    START           = 2;
                end
                
                % step through each morph level
                for morphLev = START:length(MORPH_LEVELS)
                    
                    %% load audio
                    audioDir        = fullfile(VOICE_DIR,TRAJ_DIRECTION_LIST{D},['voice' num2str(i)]);
                    audioFile       = dir(fullfile(audioDir,...
                        [sprintf('*%03d',MORPH_LEVELS(morphLev)) '%.wav']));
                    [TEMP_AUDIO,TEMP_FS]  = audioread(fullfile(audioDir,audioFile.name));
                    TEMP_AUDIO      = downsample(TEMP_AUDIO,2);
                    TEMP_FS         = round(TEMP_FS/2);
                    TEMP_DUR        = length(TEMP_AUDIO)/TEMP_FS;
%                     NORM_TEMP_AUD   = TEMP_AUDIO-min(TEMP_AUDIO);
%                     NORM_TEMP_AUD   = NORM_TEMP_AUD/max(NORM_TEMP_AUD);
%                                         figure;plot(NORM_TEMP_AUD)

                    figure(173+NOISE_COND+cond*D)
                    set(gcf,'Position',FULLSCR.*[1 1 .5 1],'Visible','off')
                    subplot(N_IDENT,length(MORPH_LEVELS),morphLev+((i-1)*length(MORPH_LEVELS)))
                    plot(TEMP_AUDIO)
                    axis tight
                    ylim([0 1])
                    % soundScrambled  = randPhase_sound(TEMP_AUDIO);
                    
%                     aud_max         = [aud_max; max(TEMP_AUDIO)];
%                     aud_min         = [aud_min; min(TEMP_AUDIO)];
                    
                    limit           = floor(length(TEMP_AUDIO)/length(FRAME_LIST));
                    
                    % parse into sound vector for each frame
                    A_y_rounded     = TEMP_AUDIO(1:length(FRAME_LIST)*limit);
                    A_y_rounded_noise     = randPhase_sound(TEMP_AUDIO(1:length(FRAME_LIST)*limit));
                    audioClips      = reshape(A_y_rounded,[],length(FRAME_LIST))';
                    audioClips_noise      = reshape(A_y_rounded_noise,[],length(FRAME_LIST))';
                    
                    % create movie
                    create_dir(fullfile(STIMOUT_DIR,['identity' num2str(i)]),'-p')
                    movieName       = fullfile(STIMOUT_DIR,['identity' num2str(i)],...
                        ['identity' num2str(i) TRAJ_DIRECTION_LIST{D} '_' ...
                        sprintf('%03d%',MORPH_LEVELS(morphLev))...
                        '_' CONDITIONS{cond} NOISE_TITLE{NOISE_COND} MOV_FTYPE]);
                    hmfw            = vision.VideoFileWriter(movieName,'AudioInputPort',true);
                    hmfw.AudioCompressor = 'MJPEG Compressor';
                    hmfw.FrameRate  = ceil(length(FRAME_LIST)/TEMP_DUR);
                    disp(['Creating movie: ' movieName])
                    
%                     figure(320)
                    
                    %% stim period
                    % step through each frame
                    for iii = 1:length(FRAME_LIST)
                        
                        % define current frame
                        frameNum                = FRAME_LIST(iii);
                        
                        TEMP_NAME               = fullfile(FACE_DIR,FACE_ORDER{i},...
                            TRAJ_DIRECTION_LIST{D},num2str(MORPH_LEVELS(morphLev)),...
                            [FACE_ORDER{i} sprintf('%03d%',MORPH_LEVELS(morphLev)) ...
                            TRAJ_DIRECTION_LIST{D} '_' sprintf('%03d%',frameNum) 'RGB.tiff']);
                        cur_frame               = addborder(imread(TEMP_NAME),...
                            20,[0 0 0],'inner');
                        cur_frame_noise         = randPhase_image(cur_frame);
                        
                        % setup audio/video from current frame
                        if NOISE_COND==1
                            switch cond
                                case 1
                                    cur_aud         = audioClips(iii,:);
                                    cur_frame       = imresize(cur_frame,SCALE);
                                case 2
                                    cur_aud         = audioClips(iii,:);
                                    cur_frame       = zeros(IM_DIMS);
                                case 3
                                    cur_aud         = zeros(size(audioClips(1,:)));
                                    cur_frame       = imresize(cur_frame,SCALE);
                            end
                            
                        else
                            switch cond
                                case 1
                                    cur_aud         = audioClips_noise(iii,:);
                                    cur_frame       = imresize(cur_frame_noise,SCALE);
                                case 2
                                    cur_aud         = audioClips_noise(iii,:);
                                    cur_frame       = zeros(IM_DIMS);
                                case 3
                                    cur_aud         = zeros(size(audioClips_noise(1,:)));
                                    cur_frame       = imresize(cur_frame_noise,SCALE);
                            end
                        end
                        
                        % save audio/video to current movie
                        step(hmfw,cur_frame,cur_aud')
%                         imshow(cur_frame)
                    end
                    release(hmfw)
                    
                    disp(['Created movie: ' movieName])
                    
                end
            end
            
            saveName                            = fullfile(STIMOUT_DIR,...
                ['Stimuli_' CONDITIONS{cond} NOISE_TITLE{NOISE_COND} '.png']);
            export_fig(gcf,saveName,'-nocrop',['-r' num2str(PRS)])

        end
        
        close all
        
        % FRAME_LIST = 1:TOT_N_FRAME
        
        %% create average identity video
        disp('Creating average identity video')
        
%         % load audio
%         audioDir                        = VOICE_DIR;
%         if noisySound
%             audioFile                   = dir(fullfile(VOICE_DIR,['voiceAve*' NOISE_TITLE '.wav']));
%         else
%             audioFile                   = dir(fullfile(VOICE_DIR,'voiceAve.wav'));
%         end
%         [TEMP_AUDIO,A_Fs]               = audioread(fullfile(audioDir,audioFile.name));
%         limit                           = floor(length(TEMP_AUDIO)/length(FRAME_LIST));
%         A_y_rounded                     = TEMP_AUDIO(1:length(FRAME_LIST)*limit);
%         audioClips                      = reshape(1:length(A_y_rounded),[],length(FRAME_LIST))';
        
        %% load audio
        [TEMP_AUDIO,TEMP_FS]            = audioread(fullfile(VOICE_DIR,'voiceAve.wav'));
        TEMP_AUDIO                      = downsample(TEMP_AUDIO,2);
        TEMP_FS                         = round(TEMP_FS/2);
        TEMP_DUR                        = length(TEMP_AUDIO)/TEMP_FS;
        limit                           = floor(length(TEMP_AUDIO)/length(FRAME_LIST));
%         NORM_TEMP_AUD                   = TEMP_AUDIO-min(TEMP_AUDIO);
%         NORM_TEMP_AUD                   = NORM_TEMP_AUD/max(NORM_TEMP_AUD);
        
        % parse into sound vector for each frame
        A_y_rounded                     = TEMP_AUDIO(1:length(FRAME_LIST)*limit);
        A_y_rounded_noise               = randPhase_sound(TEMP_AUDIO(1:length(FRAME_LIST)*limit));
        audioClips                      = reshape(A_y_rounded,[],length(FRAME_LIST))';
        audioClips_noise                = reshape(A_y_rounded_noise,[],length(FRAME_LIST))';
        
        % create movie
        movieName                       = fullfile(STIMOUT_DIR,...
                        ['Average' '_' CONDITIONS{cond} NOISE_TITLE{NOISE_COND} MOV_FTYPE]);
        hmfw                            = vision.VideoFileWriter(movieName,'AudioInputPort',true);
        hmfw.FrameRate                  = ceil(length(FRAME_LIST)/TEMP_DUR);
        hmfw.AudioCompressor            = 'MJPEG Compressor';
        
        %% stim period
        % step through each frame
        for iii = 1:length(FRAME_LIST)
            
            % define current frame
            frameNum                    = FRAME_LIST(iii);
            TEMP_NAME                   = fullfile(FACE_DIR,'Ave',...
                ['Average_' sprintf('%03d%',frameNum) 'RGB.tiff']);
            cur_frame                   = imread(TEMP_NAME);
            cur_frame_noise             = randPhase_image(cur_frame);
     
            % setup audio/video from current frame
            if NOISE_COND==1
                switch cond
                    case 1
                        cur_aud         = audioClips(iii,:);
                        cur_frame       = imresize(cur_frame,SCALE);
                    case 2
                        cur_aud         = audioClips(iii,:);
                        cur_frame       = zeros(IM_DIMS);
                    case 3
                        cur_aud         = zeros(size(audioClips(1,:)));
                        cur_frame       = imresize(cur_frame,SCALE);
                end
                
            else
                switch cond
                    case 1
                        cur_aud         = audioClips_noise(iii,:);
                        cur_frame       = imresize(cur_frame_noise,SCALE);
                    case 2
                        cur_aud         = audioClips_noise(iii,:);
                        cur_frame       = zeros(IM_DIMS);
                    case 3
                        cur_aud         = zeros(size(audioClips_noise(1,:)));
                        cur_frame       = imresize(cur_frame_noise,SCALE);
                end
            end
           
            % save audio/video to current movie
            step(hmfw,cur_frame,cur_aud')
%             imshow(cur_frame)
            
        end
        release(hmfw)
        disp(['Created movie: ' movieName])

        % clean up
        close all
        
    end
end
% disp([min(aud_min) max(aud_max)])
% keyboard
% figure
% subplot(211);plot(aud_min)
% subplot(212);plot(aud_max)