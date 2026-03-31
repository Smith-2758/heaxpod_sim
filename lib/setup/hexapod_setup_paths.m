function setup_info = hexapod_setup_paths()
project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
required_paths = build_required_paths(project_root);
current_paths = string(strsplit(path, pathsep));
added_paths = strings(0, 1);

for idx = 1:numel(required_paths)
    candidate = string(required_paths{idx});
    if strlength(candidate) == 0 || exist(candidate, 'dir') ~= 7
        continue;
    end
    if any(strcmp(current_paths, candidate))
        continue;
    end
    addpath(char(candidate));
    current_paths(end + 1) = candidate; %#ok<AGROW>
    added_paths(end + 1, 1) = candidate; %#ok<AGROW>
end

setup_info = struct();
setup_info.project_root = project_root;
setup_info.required_paths = string(required_paths(:));
setup_info.added_paths = added_paths;
end

function required_paths = build_required_paths(project_root)
required_paths = {
    project_root
    fullfile(project_root, 'lib', 'setup')
    fullfile(project_root, 'lib', 'common')
    fullfile(project_root, 'lib', 'metrics')
    fullfile(project_root, 'lib', 'remote_api')
    fullfile(project_root, 'MAIN')
    fullfile(project_root, 'MAIN', 'compare')
    fullfile(project_root, 'MAIN', '6leg_motion')
    fullfile(project_root, 'MAIN', '6leg_motion', 'ditch')
    fullfile(project_root, 'MAIN', 'black_description')
    fullfile(project_root, 'MAIN', 'black_description', 'lib_robot')
    };
end
