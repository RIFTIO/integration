*** Settings ***
Documentation     Basic Tests for Persistence Test APP.
...
...               Copyright (c) 2015 Hewlett-Packard Development Company, L.P. and others. All rights reserved.
Suite Setup       Setup Persistence Test App Environment
Suite Teardown    Cleanup Persistence Test Database
Library           SSHLibrary
Library           Collections
Library           ../../../libraries/UtilLibrary.py
Resource          ../../../libraries/KarafKeywords.txt
Resource          ../../../libraries/Utils.txt
Variables         ../../../variables/Variables.py

*** Variables ***
${username}       user1
${password}       user1
${email_addr}     user1@example.com
${location1}      BUILDING_1_FIRST_FLOOR
${location2}      BUILDING_2_FIRST_FLOOR
${device1_name}    node1
${device1_ip}     10.1.1.10
${device2_name}    node2
${device2_ip}     10.1.1.20

*** Test Cases ***
Verify User Test App
    [Documentation]    Verify the User functionality of the Persistence Test App
    ...    This test case performs the following:
    ...    1. Create a user
    ...    2. Verify user is created and can be fetched
    ...    3. Verify user is created with correct user name and email address
    ...    4. Verify unknown user cannot be authenticated
    ...    5. Disable the user
    ...    6. Verify disabled user can be fetched
    [Tags]    Persistence    TestApp
    Issue Command On Karaf Console    user:sign-up ${username} ${password} ${email_addr}
    ${output}=    Issue Command On Karaf Console    user:get-enabled
    ${string}=    Extract String To Validate    ${output}    User{username=Username{value=    0
    Should Match    ${string}    ${username}
    ${string}=    Extract String To Validate    ${output}    email=Email{value=    2
    Should Match    ${string}    ${email_addr}
    ${unknown_user}=    Set Variable    random
    ${output}=    Issue Command On Karaf Console    user:sign-in ${unknown_user} ${password}
    Should Contain    ${output}    Error executing command:
    Issue Command On Karaf Console    user:disable ${username}
    ${output}=    Issue Command On Karaf Console    user:get-disabled
    ${user_dstate}=    Set Variable    isEnabled=false
    ${data}=    Find User State    ${output}
    Should Contain    ${data}    ${user_dstate}

Verify Network Device Test App
    [Documentation]    Verify the Network Device functionality of the Persistence Test App
    ...    This test case performs the following:
    ...    1. Add a device
    ...    2. Verify device can be discovered
    ...    3. Assign a name to the device
    ...    4. Verify device name
    ...    5. Configure a location
    ...    6. Verify device location
    [Tags]    Persistence    TestApp
    Issue Command On Karaf Console    networkdevice:discover ${device1_ip}
    ${output}=    Issue Command On Karaf Console    networkdevice:get-reachable
    ${string}=    Extract String To Validate    ${output}    ipAddress=IpAddress{value=    2
    Should Match    ${string}    ${device1_ip}
    ${device_id}    Find Device Id    ${device1_ip}
    Issue Command On Karaf Console    networkdevice:set-friendly-name ${device_id} ${device1_name}
    ${data}=    Find Device Name    ${device1_ip}
    Should Match    ${data}    ${device1_name}
    Issue Command On Karaf Console    networkdevice:set-location ${device_id} ${location1}
    ${data}=    Find Device Location    ${device1_ip}    ${location1}
    Should Match    ${data}    ${location1}

Verify Data Persistency
    [Documentation]    Verify that the data that is generated by Persistence Test App can be persisted
    ...    This test case performs the following:
    ...    1. Create a user
    ...    2. Add a device and configure name and location
    ...    3. Restart the controller
    ...    4. Verify user name, email address and state are persisted
    ...    5. Verify device name and location are persisted
    [Tags]    Persistence    TestApp
    Issue Command On Karaf Console    user:sign-up ${username} ${password} ${email_addr}
    Issue Command On Karaf Console    networkdevice:discover ${device2_ip}
    ${device_id}    Find Device Id    ${device2_ip}
    Issue Command On Karaf Console    networkdevice:set-location ${device_id} ${location2}
    Issue Command On Karaf Console    networkdevice:set-friendly-name ${device_id} ${device2_name}
    Stop One Or More Controllers    ${CONTROLLER}
    Wait Until Keyword Succeeds    60s    3s    Controller Down Check    ${CONTROLLER}
    Start One Or More Controllers    ${CONTROLLER}
    UtilLibrary.Wait For Controller Up    ${CONTROLLER}    ${RESTCONFPORT}
    ${output}=    Issue Command On Karaf Console    user:get-enabled
    ${string}=    Extract String To Validate    ${output}    User{username=Username{value=    0
    Should Match    ${string}    ${username}
    ${string}=    Extract String To Validate    ${output}    email=Email{value=    2
    Should Match    ${string}    ${email_addr}
    ${data}=    Find User State    ${output}
    ${user_estate}=    Set Variable    isEnabled=true
    Should Contain    ${data}    ${user_estate}
    ${data}=    Find Device Name    ${device2_ip}
    Should Match    ${data}    ${device2_name}
    ${data}=    Find Device Location    ${device2_ip}    ${location2}
    Should Match    ${data}    ${location2}

*** Keywords ***
Extract String To Validate
    [Arguments]    ${output}    ${splitter}    ${index}
    [Documentation]    Take the output of a content, the string to be splitted and the
    ...    index of the data from the output, parse the strin and return the data that includes
    ...    user's name, user's email address, device's IP address
    ${output}=    Split Value from String    ${output}    }
    ${string}=    Get From List    ${output}    ${index}
    ${string}=    Split Value from String    ${string}    ${splitter}
    ${string}=    Get From List    ${string}    1
    [Return]    ${string}

Find Line
    [Arguments]    ${device_ip}
    [Documentation]    Take the output of networkdevice:get-reachable, find the line
    ...    with the give IP with the given IP address and return the line
    ${output}=    Issue Command On Karaf Console    networkdevice:get-reachable
    ${output}=    Split To Lines    ${output}
    ${length}=    Get Length    ${output}
    : FOR    ${INDEX}    IN RANGE    0    ${length}
    \    ${line}=    Get From List    ${output}    ${INDEX}
    \    ${data}=    Fetch From Right    ${line}    ipAddress=IpAddress{value=
    \    ${data}=    Split String    ${data}    },
    \    ${data}=    Get From List    ${data}    0
    \    Run Keyword If    '${data}' == '${device_ip}'    Exit For Loop
    [Return]    ${line}

Find Device Id
    [Arguments]    ${device_ip}
    [Documentation]    Find the device ID using its IP address
    ${line}=    Find Line    ${device_ip}
    ${id}=    Split String    ${line}    NetworkDevice{id=SerialNumber{value=
    ${id}=    Get From List    ${id}    1
    ${id}=    Fetch from Left    ${id}    }
    [Return]    ${id}

Find Device Name
    [Arguments]    ${device_ip}
    [Documentation]    Find the device's name using its IP address
    ${line}=    Find Line    ${device_ip}
    ${line}=    Split String    ${line}    ,
    ${line}=    Get From List    ${line}    -2
    ${name}=    Split String    ${line}    friendlyName=
    ${name}=    Get From List    ${name}    1
    [Return]    ${name}

Find Device Location
    [Arguments]    ${device_ip}    ${location}
    [Documentation]    Find the device's location using its IP address
    ${line}=    Find Line    ${device_ip}
    ${line}=    Split String    ${line}    ,
    ${line}=    Get From List    ${line}    3
    ${name}=    Split String    ${line}    location=
    ${name}=    Get From List    ${name}    1
    [Return]    ${location}

Find User State
    [Arguments]    ${output}
    [Documentation]    Find the user's state
    ${output}=    Split Value from String    ${output}    ,
    ${data}=    Get From List    ${output}    4
    ${data}=    Remove Space on String    ${data}
    ${data}=    Split String    ${data}    }
    [Return]    ${data}

Setup Persistence Test App Environment
    [Documentation]    Installing Persistence Related features
    Install a Feature    odl-persistence-all
    Install a Feature    odl-persistence-test-app
    Verify Feature Is Installed    odl-persistence-api
    Verify Feature Is Installed    odl-persistence-jpa-impl
    Verify Feature Is Installed    odl-persistence-test-app

Cleanup Persistence Test Database
    [Documentation]    Clear the database and uninstall Persistence Test App
    Uninstall a Feature    odl-persistence-api
    Uninstall a Feature    odl-persistence-jpa-impl
    Uninstall a Feature    odl-persistence-test-app
    Verify Feature Is Not Installed    odl-persistence-api
    Verify Feature Is Not Installed    odl-persistence-jpa-impl
    Verify Feature Is Not Installed    odl-persistence-test-app
