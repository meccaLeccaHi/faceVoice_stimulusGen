function dynamorph_merger(varargin)
%
% optional args: onScreen,showBar
%
% merge single channel images into RGB matrix and save as color image
%
% apj
% 6/17/16

if isunix
    drive                               = '/home/lab';
%     parpool('local',2)
else
    drive                               =  'K:\';
%     parpool('local',3)
end
movie_dir                               = fullfile(drive,'Cloud2','movies','human','faces');
movie_frame_dir                         = fullfile(movie_dir,'frames');
completed_frame_dir                     = fullfile(movie_dir,'fin_frames');
raw_dir                                 = fullfile(movie_frame_dir,'raw');
ave_dir                                 = fullfile(movie_frame_dir,'aves');
ave_fin_dir                             = fullfile(completed_frame_dir,'ave');
if ~exist(ave_fin_dir,'dir')
    mkdir(ave_fin_dir);
end

colors                                  = 'RGB';
figure(1)
figPos                                  = get(1,'Position');
figure(2)

% onScreen,showBar
if ~isempty(varargin)&&varargin{1}==1;
    onScreen                            = 1;
    fig1Pos                             = figPos-[figPos(3) 0 0 0];
    fig2Pos                             = figPos+[figPos(3) 0 0 0];
else
    onScreen                            = 0;
    fig1Pos                             = figPos-[figPos(3) -figPos(2) 0 0];
    fig2Pos                             = figPos+[figPos(3) figPos(2) 0 0];
end
set(1,'Position',fig1Pos);
set(2,'Position',fig2Pos);

% movie_list                              = dir(fullfile(movie_dir,'George*convert.mp4'));

% load name-pairs
text_data                               = load(fullfile(movie_dir,'facepairs.mat'));
text_data                               = text_data.text_data;
foo                                     = unique(text_data);
[~,temp_ind]                            = sort(lower(foo));
% names                                   = foo(temp_ind);
names = ...
{'Arnold-barney' 'barney-Daniel' 'Daniel-Hillary' 'Daniel-Shinzo' 'Ian-Piers' 'Ian-Tom' 'Piers-Tom'};

% traj_list                               = [25; 50; 75];
rad_morph_levels                        = [75 50 25];
hyb_morph_levels                        = [50];
tan_morph_levels                        = [75 50 25];

if ~isempty(varargin)&&varargin{2}==1;
    showBar                             = 1;
    h                                   = waitbar(0,'Merging images...');
else
    showBar                             = 0;
    disp('Merging images...')
end

% frame loop
parfor fN = 201:601
    
    %     if showBar
    %         waitbar(fN/601,h,['Merging frame: ' num2str(fN)]);
    %     else
    disp(['Merging frame: ' num2str(fN)])
    %     end
    
    color_image                         = [];
    
    % initiate gpu
    gpuDev                              = gpuDevice(1);
    
    %% merge average face
    % color channel loop
    for i = 1:length(colors)
        
        % get filenames of original images
        chan_list                       = rdir(fullfile(raw_dir,'**',...
            ['*_' sprintf('%03d',fN) colors(i) '.png']));
        chan_max                        = nan(1,length(chan_list));
        % get filenames of average images
        chan_ave                        = dir(fullfile(ave_dir,colors(i),...
            ['average_' sprintf('%03d',fN) '.png']));
        
        % if frame exists for average on this channel
        if ~isempty(chan_ave)
            
            % get max intensity values for each channel from originals
            for ii = 1:length(chan_list)
                chan_max(ii)            = max(max(imread(chan_list(ii).name)));
            end
            color_chan                  = gpuArray(imread(fullfile(ave_dir,colors(i),chan_ave.name)));
            chan_norm                   = gpuArray(color_chan*(mean(chan_max)/255));
            
            % accumulate channels
            color_image                 = gpuArray(cat(3,color_image,chan_norm));
        end
    end
    
    keyboard
    
    if ~isempty(chan_ave)
        
        % add black border to clean up white edges
        color_image_fin                 = addborder(gather(color_image),10,[0 0 0],'inner');
        
        % save average face
        if ~isempty(chan_ave)
            if onScreen==1;
                set(0,'CurrentFigure',1)
                imshow(color_image_fin);
            end
            temp_name                   = fullfile(ave_fin_dir,...
                ['average' sprintf('%03d',fN) 'RGB.png']);
            imwrite(color_image_fin,temp_name);
        else
            disp(['frame ' num2str(fN) ' skipped'])
        end
    end
    
    %% merge radial morph faces
    % identity loop
    for i = 1:length(names)
        
        faceDir                         = fullfile(movie_frame_dir,names{i});
        fin_faceDir                     = fullfile(completed_frame_dir,names{i});
        if ~exist(fin_faceDir,'dir')
            mkdir(fin_faceDir);
        end

        % morph step loop
        for ii = 1:length(rad_morph_levels)
            
            fin_trajDir                 = fullfile(completed_frame_dir,names{i},...
                num2str(rad_morph_levels(ii)));
            if ~exist(fin_trajDir,'dir')
                mkdir(fin_trajDir);
            end
            
            fileName                    = [names{i} sprintf('%03d',rad_morph_levels(ii)) ...
                '_' sprintf('%03d',fN)];
            
            color_image                 = [];
            % color channel loop
            for iii = 1:length(colors)
                
                % get filenames of morph images
                foo                     = names{i}(1:strfind(names{i},'-')-1);
                chan_im                 = dir(fullfile(raw_dir,[foo '_' ...
                    sprintf('%03d',fN) colors(iii) '.png']));
                chan_max                = nan(1,length(chan_im));
                chan_morph              = dir(fullfile(faceDir,colors(iii),...
                    [fileName '.png']));
                
                % if frame exists for morph on this channel
                if ~isempty(chan_morph)
                    
                    % get max intensity values for each channel from originals
                    for iv = 1:length(chan_im)
                        chan_max(iv)    = max(max(imread(fullfile(raw_dir,chan_im(iv).name))));
                    end
                    color_chan          = gpuArray(imread(fullfile(faceDir,colors(iii),...
                        chan_morph.name)));
                    chan_norm           = gpuArray(color_chan*(mean(chan_max)/255));
                    
                    % accumulate channels
                    color_image         = gpuArray(cat(3,color_image,chan_norm));
                end
            end
            
            if ~isempty(chan_morph)
                % add black border to clean up white edges
                color_image_fin         = addborder(gather(color_image),10,[0 0 0],'inner');
                
                if onScreen==1;
                    set(0,'CurrentFigure',2)
                    imshow(color_image_fin);
                end
                
                if ~exist(fin_trajDir,'dir')
                    mkdir(fin_trajDir);
                end
                
                % save image
                if ~isempty(chan_morph)
                    imwrite(color_image_fin,fullfile(fin_trajDir,[fileName 'RGB.png']));
                end
            end
        end
    end
    
    %% merge hybrid morph faces
    % identity loop
    for i = 1:length(text_data)
        
        morphPair                       = [text_data{i,1} '-' text_data{i,2}];
        faceDir                         = fullfile(movie_frame_dir,'hybrids',morphPair);
        fin_faceDir                     = fullfile(completed_frame_dir,'hybrids');
        if ~exist(fin_faceDir,'dir')
            mkdir(fin_faceDir);
        end
        
        % morph step loop
        for ii = 1:length(hyb_morph_levels)
            
            fin_trajDir                 = fullfile(fin_faceDir,morphPair);
            if ~exist(fin_trajDir,'dir')
                mkdir(fin_trajDir);
            end
            
            fileName                    = [morphPair sprintf('%03d',hyb_morph_levels(ii)) ...
                '_' sprintf('%03d',fN)];
            
            color_image                 = [];
            % color channel loop
            for iii = 1:length(colors)
                
                % get filenames of morph images
%                 foo                     = names{i}(1:strfind(names{i},'-')-1);
%                 chan_im                 = dir(fullfile(raw_dir,[foo '_' ...
%                     sprintf('%03d',fN) colors(iii) '.png']));

                chan_im                 = dir(fullfile(raw_dir,[text_data{i,1} '_' ...
                    sprintf('%03d',fN) colors(iii) '.png']));
                chan_max                = nan(1,length(chan_im));
                chan_morph              = dir(fullfile(faceDir,colors(iii),...
                    [fileName '.png']));
                
                % if frame exists for morph on this channel
                if ~isempty(chan_morph)
                    
                    % get max intensity values for each channel from originals
                    for iv = 1:length(chan_im)
                        chan_max(iv)    = max(max(imread(fullfile(raw_dir,chan_im(iv).name))));
                    end
                    color_chan          = gpuArray(imread(fullfile(faceDir,colors(iii),...
                        chan_morph.name)));
                    chan_norm           = gpuArray(color_chan*(mean(chan_max)/255));
                    
                    % accumulate channels
                    color_image         = gpuArray(cat(3,color_image,chan_norm));
                end
            end
            
            if ~isempty(chan_morph)
                % add black border to clean up white edges
                color_image_fin         = addborder(gather(color_image),10,[0 0 0],'inner');
                
                if onScreen==1;
                    set(0,'CurrentFigure',2)
                    imshow(color_image_fin);
                end
                
                % save image
                if ~isempty(chan_morph)
                    imwrite(color_image_fin,fullfile(fin_trajDir,[fileName 'RGB.png']));
                end
            end
            
        end
    end
    
    
    %% merge tangential morph faces
    % identity loop
    tanMorphList                        = dir(fullfile(movie_frame_dir,'tang_morphs'));
    tanMorphList                        = tanMorphList(arrayfun(@(x) x.name(1),tanMorphList)~='.');
    
    for i = 1:length(tanMorphList)
       
        morphPair                       = tanMorphList(i).name;
        faceDir                         = fullfile(movie_frame_dir,'tang_morphs',morphPair);
        fin_faceDir                     = fullfile(completed_frame_dir,'tang_morphs');
        if ~exist(fin_faceDir,'dir')
            mkdir(fin_faceDir);
        end
        
        % morph step loop
        for ii = 1:length(tan_morph_levels)
            
            fin_trajDir                 = fullfile(fin_faceDir,morphPair);
            if ~exist(fin_trajDir,'dir')
                mkdir(fin_trajDir);
            end
     
            fileName                    = [morphPair sprintf('%03d',tan_morph_levels(ii)) ...
                '_' sprintf('%03d',fN)];
            
            color_image                 = gpuArray([]);
            % color channel loop
            for iii = 1:length(colors)
                
                % get filenames of morph images
                chan_im                 = dir(fullfile(raw_dir,[text_data{i,1} '_' ...
                    sprintf('%03d',fN) colors(iii) '.png']));
                chan_max                = gpuArray(nan(1,length(chan_im)));
                chan_morph              = dir(fullfile(faceDir,colors(iii),...
                    [fileName '.png']));
                
                % if frame exists for morph on this channel
                if ~isempty(chan_morph)
                    
                    % get max intensity values for each channel from originals
                    for iv = 1:length(chan_im)
                        chan_max(iv)    = max(max(imread(fullfile(raw_dir,chan_im(iv).name))));
                    end
                    color_chan          = gpuArray(imread(fullfile(faceDir,colors(iii),...
                        chan_morph.name)));
                    chan_norm           = gpuArray(color_chan*(mean(chan_max)/255));
                    
                    % accumulate channels
                    color_image         = gpuArray(cat(3,color_image,chan_norm));
                end
            end
            
            if ~isempty(chan_morph)
                % add black border to clean up white edges
                color_image_fin         = addborder(gather(color_image),10,[0 0 0],'inner');
                
                if onScreen==1;
                    set(0,'CurrentFigure',2)
                    imshow(color_image_fin);
                end
                
                % save image
                if ~isempty(chan_morph)
                    imwrite(color_image_fin,fullfile(fin_trajDir,[fileName 'RGB.png']));
                end
            end
        end
    end
    
    reset(gpuDev)


end

close all
end