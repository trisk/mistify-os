*** Settings ***
Documentation	This test suite runs the buildmistify script in a
...		container and checks progress along the way.
...
...	NOTE: This can take two or three hours to complete depending
...	upon network and computer performance. The container must have already
...	been created and provisioned.

Library		String
Resource	test/resources/mistify.robot
Resource	test/resources/ssh.robot
Resource	test/resources/lxc.robot

Suite Setup             Setup Testsuite
Suite Teardown          Teardown Testsuite

*** Variables ***
${prompt}=	${USER}@${DISTRO_LONG_NAME}
${mistifybuilddir}=	~/build

# When building use a download cache outside the build tree. No need to
# download the same files over and over again when reusing containers.
${downloaddir}=	${mistifybuilddir}/downloads

@{checkpoints}=
...	Using Buildroot located at:
...	Fetching Buildroot branch
...	Using Buildroot branch:
...	The kernel headers version is:
...	Using toolchain variation:
...	Configuring the toolchain build.
...	Installing user-supplied crosstool-NG configuration
...	Installing GMP for host: done
...	Installing MPFR for host: done
...	Installing ISL for host: done
...	Installing CLooG for host: done
...	Installing MPC for host: done
...	Installing binutils for host: done
...	Installing pass-1 core C compiler: done
...	Installing kernel headers: done
...	Installing C library headers & start files: done
...	Installing pass-2 core C compiler: done
...	Installing C library: done
...	Installing final compiler: done
...	Using go located at:
...	Building compilers and Go bootstrap tool for host, linux/amd64
...	Building packages and commands for linux/amd64
...	Installed Go for linux/amd64

*** Test Cases ***
Get Container IP Address
    Log To Console  \nGetting IP address for ${containername}
    ${_o}=	Container IP Address  ${containername}
    Should Contain X Times	${_o}  \.  3
    Set Suite Variable  ${ip}  ${_o}

Connect To The Container
    [Documentation]	Connect to the container.
    ...
    ...		This assumes the container has been created and the
    ...		user created using the calling user's credentials by
    ...		the AddUserToContainer script.
    Log To Console  \nLogging in as ${USER} to container at IP: ${ip}
    Login to SUT  ${ip}  ${USER}  ${USER}

Remove Previous Build
    [Documentation]	This test suite verifies a complete rebuild in an
    ...			existing container.
    ...
    ...		Remove a previous build if it exists.
    ...		NOTE: This assumes the toolchain, go and the build targets
    ...		are all in their default locations.
    ssh.Set Client Configuration  timeout=1m
    ssh.Write  mkdir -p ${mistifybuilddir}
    ssh.Write  cd ${mistifybuilddir}
    ssh.Write  rm -rf ${MISTIFY_CLONE_DIR}
    ssh.Read Until  ${prompt}
    ssh.Write  ls
    ${_o}=  ssh.Read Until  ${prompt}
    Should Not Contain  ${_o}  ${MISTIFY_OS_REPO}

Clone Mistify
    [Documentation]	Clone the Mistify-OS repo to prepare for the build.
    ...
    ...		This assumes the container has already been created
    ...		and provisioned. However, the clone of the Mistify-OS
    ...		repo has not yet occurred.
    ssh.Set Client Configuration  timeout=5m
    ssh.Write  cd ${mistifybuilddir}
    ssh.Write	git clone ${MISTIFY_GIT_URL} ${MISTIFY_CLONE_DIR}
    ${_o}=	ssh.Read Until  ${prompt}
    Should Contain  ${_o}  ... done.

Switch To Branch
    [Documentation]	Checkout the branch to be built.
    ...
    ...		This uses the variable MISTIFYBRANCH which was passed on the
    ...		command line by the "testmistify" script.
    Log To Console  \nSwitching to branch: ${MISTIFYBRANCH}
    ssh.Write  cd ${mistifybuilddir}/${MISTIFY_CLONE_DIR}
    ${_o}=	ssh.Read Until  ${prompt}
    ssh.Write	git fetch
    ${_o}=	ssh.Read Until  ${prompt}
    ssh.Write	git checkout ${MISTIFYBRANCH}
    ${_o}=	ssh.Read Until  ${prompt}
    ssh.Write	git status
    ${_o}=	ssh.Read Until  ${prompt}
    Should Contain  ${_o}  ${MISTIFYBRANCH}

Start The Build
    [Documentation]	From within the cloned directory start the buildmistify
    ...			script.
    ...
    ...		NOTE: The user prompt needs to be configured to include the
    ...		current path.
    ssh.Write  ls
    ${_o}=	ssh.Read Until  ${prompt}
    Should Contain  ${_o}  buildmistify
    ssh.Write  ./buildmistify -d ${downloaddir} --resetmasters

Build Tools
    [Documentation]	Build the cross tools and go compiler.
    ssh.Set Client Configuration  timeout=20m
    :FOR  ${_checkpoint}  IN  @{checkpoints}
    	\  Log To Console  \nWaiting for: ${_checkpoint}
    	\  ${_o}=  ssh.Read Until  ${_checkpoint}
    	\  ${_t}=  Get Time  |  NOW
    	\  Log To Console  Checkpoint at: ${_t}
    ${_o}=	ssh.Read Until  Logging the build output to
    ${_l}=	Get Lines Containing String  ${_o}  Logging the build output to
    Log To Console  \n${_l}

Monitor The Build
    Set Test Variable  ${_t}	1	# Iteration time.
    Set Test Variable  ${_m}	180	# Maximum time to build even on a slow machine.
    ssh.Set Client Configuration  timeout=${_t}m
    ssh.Read Until  make: Entering directory
    Log To Console  \n
    # In absence of a while loop using a really big range.
    # Also can't reliably do checkpoints because the build sequence depends
    # upon the package dependencies.
    :FOR  ${_i}  IN RANGE  ${_m}
    	\  ${_t}=  Get Time  |  NOW
    	\  Log To Console  \nCheckpoint: ${_i} at: ${_t}
    	\  ${_s}  ${_o}=  Run Keyword And Ignore Error  ssh.Read Until  make: Leaving directory
    	\  Exit For Loop If  '${_s}' == 'PASS'
    	\  ${_l}=  Get Lines Containing String  ${_o}  : Entering directory
    	\  Log To Console  ${_l}
    ${_o}=	ssh.Read Until  rootfs.cpio
    Should Contain  ${_o}  bzImage.buildroot
    Should Contain  ${_o}  initrd.buildroot
    ssh.Set Client Configuration  timeout=3s

Verify The Build
    Log To Console  Checking the build log file.

*** Keywords ***
Setup Testsuite
    # The variable CONTAINER_ID is passed on the test mistify command line
    # by the Jenkins job to uniquely identify containers and avoid collision
    # on the same container. (e.g. ./testmistify -- -v CONTAINER_ID:<id>)
    # WARNING: The containers must already exist have have been previously
    # provisioned. There needs to be one container per Jenkins executor.
    ${_id}=  Get Variable Value  ${CONTAINER_ID}  ${EMPTY}
    ${containername}=	Catenate  SEPARATOR=  ${DISTRO_LONG_NAME}  ${_id}
    Set Suite Variable  ${containername}

    ${_rc}=	Use Container
    ...	${containername}	${DISTRO_NAME}
    ...	${DISTRO_VERSION_NAME}	${DISTRO_ARCH}
    Log To Console	\nUsing container: ${containername}
    Run Keyword Unless  ${_rc} == 0
    ...	Log To Console	\nContainer could not be created.
    ...		WARN

Teardown Testsuite
    ssh.Close All Connections
    Stop Container	${containername}

