*** Settings ***
Documentation     Cbench Latency and Throughput tests can be run from an external
...                 cbench.
...                 If cbench is run with a medium number of switches or higher (e.g. 32+)
...                 the normal openflow operations seem to break.
...                 BUG:  https://bugs.opendaylight.org/show_bug.cgi?id=2897
Suite Setup       Cbench Suite Setup
Force Tags        cbench
Library           String
Resource          ../../../libraries/Utils.txt
Resource          ../../../libraries/KarafKeywords.txt


*** Variables ***
${throughput_threshold}     30000
${latency_threshold}        10000
${switch_count}             8
${duration_in_secs}         12
${loops}                    10
${num_of_unique_macs}       10000
${cbench_system}            ${MININET}
${cbench_executable}        /usr/local/bin/cbench

*** Testcases ***
Cbench Throughput Test
    [Documentation]     cbench executed in throughput mode (-t).  Test parameters have defaults, but can be overridden
    ...     on the pybot command line
    [Tags]  throughput
    [Timeout]   ${test_timeout}
    Log    Cbench tests using ${loops} iterations of ${duration_in_secs} second tests. Switch Count: ${switch_count}. Unique MACS to cycle: ${num_of_unique_macs}
    Run Cbench And Log Results  -t -m ${duration_in_ms} -M ${num_of_unique_macs} -s ${switch_count} -l ${loops}     ${throughput_threshold}

Cbench Latency Test
    [Documentation]     cbench executed in default latency mode.  Test parameters have defaults, but can be overridden
    ...     on the pybot command line
    [Tags]  latency
    [Timeout]   ${test_timeout}
    Log    Cbench tests using ${loops} iterations of ${duration_in_secs} second tests. Switch Count: ${switch_count}. Unique MACS to cycle: ${num_of_unique_macs}
    Run Cbench And Log Results  -m ${duration_in_ms} -M ${num_of_unique_macs} -s ${switch_count} -l ${loops}     ${latency_threshold}

*** Keywords ***
Run Cbench And Log Results
    [Arguments]    ${cbench_args}    ${average_threshold}
    ${output}=  Run Command On Remote System    ${cbench_system}   ${cbench_executable} -c ${CONTROLLER} ${cbench_args}  prompt_timeout=${test_timeout}
    Log     ${output}
    Should Contain    ${output}    RESULT
    ${result_line}=    Get Lines Containing String    ${output}    RESULT
    @{results_list}=    Split String    ${result_line}
    Log    ${results_list[5]}
    Log    ${results_list[7]}
    @{result_name_list}=    Split String    ${results_list[5]}    /
    @{result_value_list}=    Split String    ${results_list[7]}    /
    ${num_stats}=    Get Length    ${result_name_list}
    : FOR    ${i}    IN RANGE    0    ${num_stats}
    \    Log    ${result_name_list[${i}]} :: ${result_value_list[${i}]}
    ${min}=    Set Variable    ${result_value_list[${0}]}
    ${max}=    Set Variable    ${result_value_list[${1}]}
    ${average}=    Set Variable    ${result_value_list[${2}]}
    ${stdev}=    Set Variable    ${result_value_list[${3}]}
    ${date}=    Get Time    d,m,s
    Log    CBench Result: ${date},${cbench_args},${min},${max},${average},${stdev}
    Should Be True    ${average} > ${average_threshold}     Flow mod per/sec threshold was not met

Cbench Suite Setup
    ${duration_in_ms}           Evaluate    ${duration_in_secs} * 1000
    Set Suite Variable  ${duration_in_ms}
    ##Setting the test timeout dynamically in case larger values on command line override default
    ${test_timeout}             Evaluate    (${loops} * ${duration_in_secs}) * 1.5
    Set Suite Variable  ${test_timeout}
    Verify File Exists On Remote System     ${cbench_system}    ${cbench_executable}
    Should Be True  ${loops} >= 2   If number of loops is less than 2, cbench will not run
    Verify Feature Is Installed     odl-openflowplugin-drop-test