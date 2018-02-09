$ErrorActionPreference = "Stop"

$NODE_JS_VERSION = "4.8.5"
$DOCKER_VERSION = "17.06.2-ee-5"
$DOCKER_CONFIG_FILE="C:\ProgramData\Docker\config\daemon.json"

$SHIPPABLE_RUNTIME_DIR = "$env:USERPROFILE\Shippable\Runtime"
$BASE_UUID = New-Guid
$BASE_DIR = "$SHIPPABLE_RUNTIME_DIR\$BASE_UUID"
$CONTAINER_RUNTIME_DIR = "$env:USERPROFILE\Shippable\Runtime"
$CONTAINER_BASE_DIR = "$CONTAINER_RUNTIME_DIR\$BASE_UUID"

$REQPROC_DIR = "$BASE_DIR\reqProc"
$CONTAINER_REQPROC_DIR = "$CONTAINER_BASE_DIR\reqProc"

$REQEXEC_DIR = "$BASE_DIR\reqExec"
$CONTAINER_REQEXEC_DIR = "$CONTAINER_BASE_DIR\reqExec"
$REQEXEC_BIN_DIR = "$BASE_DIR\reqExec"
$REQEXEC_BIN_PATH = "$REQEXEC_BIN_DIR\$NODE_ARCHITECTURE\$NODE_OPERATING_SYSTEM\dist\main\main.exe"

$REQKICK_DIR = "$BASE_DIR\reqKick"
$CONTAINER_REQKICK_DIR = "$CONTAINER_BASE_DIR\reqKick"
$REQKICK_SERVICE_DIR = "$REQKICK_DIR\init\$NODE_ARCHITECTURE\$NODE_OPERATING_SYSTEM"
$REQKICK_CONFIG_DIR = "$SHIPPABLE_RUNTIME_DIR\config\reqKick"

$BUILD_DIR = "$BASE_DIR\build"
$CONTAINER_BUILD_DIR = "$CONTAINER_BASE_DIR\build"
$STATUS_DIR = "$BUILD_DIR\status"
$SCRIPTS_DIR = "$BUILD_DIR\scripts"

# TODO: this needs to be hardcoded until we have a way to specify it in the API
$EXEC_IMAGE = "drydock/w16reqproc:$SHIPPABLE_RELEASE_VERSION"

# For mounting execTemplates for dev
$IMAGE_EXEC_TEMPLATES_DIR = "C:\Users\ContainerAdministrator\Shippable\reqProc\execTemplates"
$HOST_EXEC_TEMPLATES_DIR="C:\Users\Administrator\Desktop\execTemplates"

$REQPROC_MOUNTS = ""
$REQPROC_ENVS = ""
$REQPROC_OPTS = ""
$REQPROC_CONTAINER_NAME_PATTERN = "reqProc"
$REQPROC_CONTAINER_NAME = "$REQPROC_CONTAINER_NAME_PATTERN-$BASE_UUID"
$REQKICK_SERVICE_NAME_PATTERN = "shippable-reqKick@"

# TODO: update container directories while mounting
$DEFAULT_TASK_CONTAINER_MOUNTS = "-v ${BUILD_DIR}:${CONTAINER_BUILD_DIR} -v ${REQEXEC_DIR}:${CONTAINER_REQEXEC_DIR}"
$TASK_CONTAINER_COMMAND = "$CONTAINER_REQEXEC_DIR\$NODE_ARCHITECTURE\$NODE_OPERATING_SYSTEM\dist\main\main.exe"
$DEFAULT_TASK_CONTAINER_OPTIONS = "-d --rm"
$DOCKER_CLIENT_LATEST = "C:\Program Files\Docker\docker.exe"

Function create_shippable_dir() {
  if (!(Test-Path $SHIPPABLE_RUNTIME_DIR)) {
    mkdir -p "$SHIPPABLE_RUNTIME_DIR"
  }
}

Function check_win_containers_enabled() {
  Write-Output "Checking if Windows Containers are enabled"
  $winConInstallState = (Get-WindowsFeature containers).InstallState
  if ($winConInstallState -ne "Installed") {
    Write-Error "Windows Containers must be enabled. Please install the feature, restart this machine and run this script again."
    exit -1
  }
}

Function install_prereqs() {
  Write-Output "Enabling ChocolateyGet"
  Install-PackageProvider ChocolateyGet -Force

  Write-Output "Checking for node.js v$NODE_JS_VERSION"
  $nodejs_package = Get-Package nodejs -provider ChocolateyGet -ErrorAction SilentlyContinue
  if (!$nodejs_package -or ($nodejs_package.Version -ne "$NODE_JS_VERSION")) {
    Write-Output "Installing node.js v$NODE_JS_VERSION"
    Install-Package -ProviderName ChocolateyGet -Name nodejs -RequiredVersion $NODE_JS_VERSION -Force
  }

  Write-Output "Checking for git"
  $git_package = Get-Package git -provider ChocolateyGet -ErrorAction SilentlyContinue
  if (!$git_package) {
    Write-Output "Installing git"
    Install-Package -ProviderName ChocolateyGet -Name git -Force
  }

  Write-Output "Refreshing PATH"
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

  Write-Output "Installing global node packages"
  npm install pm2 pm2-windows-startup -g
  pm2-startup install

  Write-Output "Installing shipctl"
  & "$NODE_SHIPCTL_LOCATION/$NODE_ARCHITECTURE/$NODE_OPERATING_SYSTEM/install.ps1"
}

Function docker_install() {
  Write-Output "Installing DockerProvider module"
  Install-Module DockerProvider -Force

  Write-Output "Looking for Docker package"
  $docker_package = Get-Package docker -ProviderName DockerProvider -ErrorAction SilentlyContinue
  if (!$docker_package -or $docker_package.Version -ne "$DOCKER_VERSION") {
    Write-Output "Installing Docker v$DOCKER_VERSION"
    Install-Package Docker -ProviderName DockerProvider -RequiredVersion $DOCKER_VERSION -Force
  }

  Write-Output "Verifying Docker service has started"
  $dockerService = Get-Service docker

  if ($dockerService.Status -ne "Running") {
    Start-Service docker
  }

  wait_for_docker

  # Output docker version
  & "docker" -v
}

Function wait_for_docker() {
  # wait for a few seconds for Docker to Start
  Do {
    Write-Progress -Activity "Waiting for Docker to respond"
    Start-Sleep -s 1
    & "docker" ps > out.txt 2>&1
  }	While ($LastExitCode -eq 1)

  Write-Output "Docker is running"
}
Function check_docker_opts() {
  Write-Output "Enforcing docker daemon config"
  $script_dir = Split-Path -Path $MyInvocation.ScriptName
  Copy-Item $script_dir\daemon.json $DOCKER_CONFIG_FILE -Force

  Write-Output "Restarting docker service"
  Restart-Service docker

  wait_for_docker

  # Output docker info
  & "docker" info

  # Get docker NAT gateway ip address
  $global:DOCKER_NAT_IP=(Get-NetIPConfiguration | Where-Object InterfaceAlias -eq "vEthernet (HNS Internal NIC)").IPv4Address.IPAddress
}

Function remove_reqKick() {
  Write-Output "Remove existing reqKick"

  pm2 delete all /shippable-reqKick*/
}

Function remove_reqProc() {
  Write-Output "Remove existing reqProc containers"
  docker ps -a --filter "NAME=$REQPROC_CONTAINER_NAME_PATTERN" --format '{{.Names}}' | %{ docker rm -f $_ }
}

Function setup_mounts() {
  if (Test-Path $SHIPPABLE_RUNTIME_DIR) {
    Write-Output "Deleting Shippable runtime directory"
    Remove-Item -recur -force $SHIPPABLE_RUNTIME_DIR
  }

  if (!(Test-Path $BASE_DIR)) {
    mkdir -p $BASE_DIR
  }

  if (!(Test-Path $REQPROC_DIR)) {
    mkdir -p $REQPROC_DIR
  }

  if (!(Test-Path $REQEXEC_DIR)) {
    mkdir -p $REQEXEC_DIR
  }

  if (!(Test-Path $REQKICK_DIR)) {
    mkdir -p $REQKICK_DIR
  }

  if (!(Test-Path $BUILD_DIR)) {
    mkdir -p $BUILD_DIR
  }

  $global:REQPROC_MOUNTS= " -v ${BASE_DIR}:${CONTAINER_BASE_DIR} -v ${HOST_EXEC_TEMPLATES_DIR}:${IMAGE_EXEC_TEMPLATES_DIR} "
}

Function setup_envs() {
  $global:REQPROC_ENVS = " -e SHIPPABLE_AMQP_URL=$SHIPPABLE_AMQP_URL " + `
    "-e SHIPPABLE_AMQP_DEFAULT_EXCHANGE=$SHIPPABLE_AMQP_DEFAULT_EXCHANGE " + `
    "-e SHIPPABLE_API_URL=$SHIPPABLE_API_URL " + `
    "-e LISTEN_QUEUE='$LISTEN_QUEUE' " + `
    "-e NODE_ID=$NODE_ID " + `
    "-e RUN_MODE=$RUN_MODE " + `
    "-e SUBSCRIPTION_ID=$SUBSCRIPTION_ID " + `
    "-e NODE_TYPE_CODE=$NODE_TYPE_CODE " + `
    "-e BASE_DIR='$CONTAINER_BASE_DIR' " + `
    "-e REQPROC_DIR='$CONTAINER_REQPROC_DIR' " + `
    "-e REQEXEC_DIR='$CONTAINER_REQEXEC_DIR' " + `
    "-e REQKICK_DIR='$CONTAINER_REQKICK_DIR' " + `
    "-e BUILD_DIR='$CONTAINER_BUILD_DIR' " + `
    "-e REQPROC_CONTAINER_NAME='$REQPROC_CONTAINER_NAME' " + `
    "-e DEFAULT_TASK_CONTAINER_OPTIONS='$DEFAULT_TASK_CONTAINER_OPTIONS' " + `
    "-e EXEC_IMAGE=$EXEC_IMAGE " + `
    "-e TASK_CONTAINER_COMMAND='$TASK_CONTAINER_COMMAND' " + `
    "-e DEFAULT_TASK_CONTAINER_MOUNTS='$DEFAULT_TASK_CONTAINER_MOUNTS' " + `
    "-e DOCKER_CLIENT_LATEST='$DOCKER_CLIENT_LATEST' " + `
    "-e SHIPPABLE_DOCKER_VERSION='$DOCKER_VERSION' " + `
    "-e IS_DOCKER_LEGACY=false " + `
    "-e SHIPPABLE_NODE_ARCHITECTURE=$NODE_ARCHITECTURE " + `
    "-e SHIPPABLE_NODE_OPERATING_SYSTEM=$NODE_OPERATING_SYSTEM " + `
    "-e SHIPPABLE_RELEASE_VERSION=$SHIPPABLE_RELEASE_VERSION " + `
    "-e IMAGE_EXEC_TEMPLATES_DIR='$IMAGE_EXEC_TEMPLATES_DIR' " + `
    "-e DOCKER_HOST=${DOCKER_NAT_IP}:2375"
}

Function setup_opts() {
  $global:REQPROC_OPTS= " -d " + `
    "--restart=always " + `
    "--name=$REQPROC_CONTAINER_NAME "
}

Function boot_reqProc() {
  Write-Output "Boot reqProc..."
  # docker pull $EXEC_IMAGE

  $start_cmd = "docker run $global:REQPROC_OPTS $global:REQPROC_MOUNTS $global:REQPROC_ENVS $EXEC_IMAGE"
  Write-Output "Executing docker run command: " $start_cmd
  iex "$start_cmd"

  $cmd = "docker exec $REQPROC_CONTAINER_NAME powershell git init"
  Write-Output "running git init"
  iex "$cmd"

  $add_remote = "docker exec $REQPROC_CONTAINER_NAME powershell git remote add scriptnull https://github.com/scriptnull/reqProc"
  Write-Output "Adding scriptnull remote"
  iex "$add_remote"

  $fetch_windows = "docker exec $REQPROC_CONTAINER_NAME powershell git fetch scriptnull windows"
  Write-Output "Fetching windows branch"
  iex "$fetch_windows"

  $reset_windows = "docker exec $REQPROC_CONTAINER_NAME powershell git reset scriptnull/windows --hard"
  Write-Output "Resetting windows branch"
  iex "$reset_windows"

  $restart_reqproc = "docker restart $REQPROC_CONTAINER_NAME"
  Write-Output "Restarting ReqProc Container"
  iex "$restart_reqproc"
}

Function boot_reqKick() {
  echo "Booting up reqKick service..."

  git clone https://github.com/scriptnull/reqKick.git $REQKICK_DIR
  pushd $REQKICK_DIR
  git checkout win-x
  npm install

  #$reqkick_env_template = "$REQKICK_SERVICE_DIR/shippable-reqKick@.yml.template"
  #New-Item -ItemType Directory -Force -Path $REQKICK_CONFIG_DIR
  #$reqkick_env = "$REQKICK_CONFIG_DIR/shippable-reqKick.yml"
  #
  #if (!(Test-Path "$reqkick_env_template")) {
  #  Write-Error "Reqkick env template file not found: $reqkick_env_template"
  #  exit -1
  #}

  #Write-Output "Writing reqKick specific envs to $reqkick_env"
  #$template=(Get-Content $reqkick_env_template)
  #$template=$template.replace("{{UUID}}", $BASE_UUID)
  #$template=$template.replace("{{STATUS_DIR}}", $STATUS_DIR)
  #$template=$template.replace("{{SCRIPTS_DIR}}", $SCRIPTS_DIR)
  #$template=$template.replace("{{RUN_MODE}}", $RUN_MODE)
  #$template=$template.replace("{{REQEXEC_BIN_PATH}}", $REQEXEC_BIN_PATH)
  #$template=$template.replace("{{REQKICK_DIR}}", $REQKICK_DIR) | Set-Content $reqkick_env

  #pm2 start $REQKICK_CONFIG_DIR/shippable-reqKick.yml
  #pm2 save

  $stdout_file = "$REQKICK_DIR\out.txt"
  $stderr_file = "$REQKICK_DIR\ err.txt"

  nssm install reqkick node reqKick.app.js
  nssm set reqkick AppEnvironmentExtra STATUS_DIR=$STATUS_DIR
  nssm set reqkick AppEnvironmentExtra SCRIPTS_DIR=$SCRIPTS_DIR
  nssm set reqkick AppEnvironmentExtra RUN_MODE=$RUN_MODE
  nssm set reqkick AppEnvironmentExtra REQEXEC_BIN_PATH=$REQEXEC_BIN_PATH
  echo $null >> $stdout_file
  echo $null >> $stderr_file
  nssm set reqkick AppStdout $stdout_file
  nssm set reqkick AppStderr $stderr_file
  nssm start reqkick

  popd
}


create_shippable_dir
check_win_containers_enabled
install_prereqs
docker_install
check_docker_opts
remove_reqKick
remove_reqProc
setup_mounts
setup_envs
setup_opts
boot_reqProc
boot_reqKick

exit 0;
