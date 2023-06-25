// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EmployeeStockOptionPlan {
    // *todo 1. Define the necessary data structures and variables
    // Structure to hold vesting schedule for an employee
    struct VestingSchedule {
        uint256 cliffDuration; // Cliff duration in seconds
        uint256 vestingDuration; // Total vesting duration in seconds
        uint256 totalOptions; // Total number of options granted
        uint256 exercisedOptions; // Number of options exercised so far
        uint256 startTime; // Start time of the vesting schedule
    }

    // Structure to hold information about an employee
    struct Employee {
        bool isActive; // Flag to indicate whether the employee is active
        uint256 totalGrantedOptions; // Total number of options granted to the employee
        uint256 totalUnAllocatedOptions; // Total number of unallocated options to the employee
        uint256 totalExercisedOptions; // Total number of options exercised by the employee
        uint256 vestingScheduleCount; // Total number of vesting schedules
        mapping(uint256 => VestingSchedule) vestingSchedules; // Mapping of vesting schedules by index
    }

    address public owner; // Contract owner address

    mapping(address => Employee) public employees; // Mapping of employees by address

    // *todo end

    // *todo 2. Define the necessary events
    event StockOptionsGranted(address indexed employee, uint256 options);

    event VestingScheduleSet(
        address indexed employee,
        uint256 index,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 totalOptions
    );

    event OptionsExercised(
        address indexed employee,
        uint256 index,
        uint256 amount
    );

    event OptionsTransferred(
        address indexed from,
        address indexed to,
        uint256 index,
        uint256 amount
    );

    // *todo end

    // *todo 3. Define the constructor
    constructor() {
        owner = msg.sender;
    }

    // *todo end

    // *todo 4. Implement the functions for granting stock options
    function grantStockOptions(
        address employee,
        uint256 options
    ) external onlyOwner {
        require(
            !employees[employee].isActive,
            "Options have already been granted to this employee."
        );

        employees[employee].isActive = true;
        employees[employee].totalGrantedOptions = options;
        employees[employee].totalUnAllocatedOptions = options;

        emit StockOptionsGranted(employee, options);
    }

    // *todo end

    // *todo 5. Implement the functions for setting the vesting schedule
    function setVestingSchedule(
        address employee,
        uint256 index,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 totalOptions
    ) external onlyOwner onlyActiveEmployee(employee) {
        require(
            index == _getVestingScheduleCount(employee),
            "Vesting schedule index must be incremental."
        );
        require(
            totalOptions <= employees[employee].totalUnAllocatedOptions,
            "Cannot grant more options than the total granted options."
        );

        employees[employee].vestingSchedules[index] = VestingSchedule(
            cliffDuration,
            vestingDuration,
            totalOptions,
            0,
            block.timestamp
        );

        employees[employee].vestingScheduleCount += 1;
        employees[employee].totalUnAllocatedOptions -= totalOptions;

        emit VestingScheduleSet(
            employee,
            index,
            cliffDuration,
            vestingDuration,
            totalOptions
        );
    }

    // *todo end

    // *todo 6. Implement the functions for exercising options
    function exerciseOptions(
        uint256 scheduleIndex,
        uint256 amount
    ) external onlyActiveEmployee(msg.sender) {
        require(
            scheduleIndex < _getVestingScheduleCount(msg.sender),
            "Invalid vesting schedule index."
        );

        require(
            amount <= _getScheduleVestedOptions(msg.sender, scheduleIndex),
            "Insufficient vested options."
        );

        uint256 exercisedOptions = employees[msg.sender]
            .vestingSchedules[scheduleIndex]
            .exercisedOptions;

        employees[msg.sender].vestingSchedules[scheduleIndex].exercisedOptions =
            exercisedOptions +
            amount;

        emit OptionsExercised(msg.sender, scheduleIndex, amount);
    }

    // *todo end

    // *todo 7. Implement the functions for tracking vested and exercised options
    // *todo end

    // *todo 8. Implement the necessary modifiers and access control
    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the contract owner can call this function."
        );
        _;
    }

    modifier onlyActiveEmployee(address employee) {
        require(employees[employee].isActive, "The employee is not active.");
        _;
    }

    // *todo end

    // *todo 9. Add any additional functions or modifiers as needed
    function transferOptions(
        address to,
        uint256 scheduleIndex,
        uint256 amount
    ) external onlyActiveEmployee(msg.sender) onlyActiveEmployee(to) {
        address from = msg.sender;

        require(
            scheduleIndex < _getVestingScheduleCount(from),
            "Invalid vesting schedule index."
        );

        require(
            _isVestingScheduleCompleted(from, scheduleIndex),
            "Vesting schedule is not completed."
        );

        require(
            amount <= _getScheduleVestedOptions(from, scheduleIndex),
            "Insufficient vested options."
        );

        uint256 exercisedOptions = employees[from]
            .vestingSchedules[scheduleIndex]
            .exercisedOptions;

        employees[from].vestingSchedules[scheduleIndex].exercisedOptions =
            exercisedOptions +
            amount;

        employees[to].totalGrantedOptions += amount;

        emit OptionsTransferred(from, to, scheduleIndex, amount);
    }

    function _isVestingScheduleCompleted(
        address employee,
        uint256 scheduleIndex
    ) internal view onlyActiveEmployee(employee) returns (bool) {
        VestingSchedule memory schedule = employees[employee].vestingSchedules[
            scheduleIndex
        ];
        uint256 currentTime = block.timestamp;
        uint256 endTime = schedule.startTime + schedule.vestingDuration;

        return currentTime >= endTime;
    }

    function _getVestingScheduleCount(
        address employee
    ) internal view returns (uint256) {
        return employees[employee].vestingScheduleCount;
    }

    function _getScheduleVestedOptions(
        address employee,
        uint256 scheduleIndex
    ) internal view onlyActiveEmployee(employee) returns (uint256) {
        if (scheduleIndex >= _getVestingScheduleCount(employee)) {
            return 0;
        }

        VestingSchedule memory schedule = employees[employee].vestingSchedules[
            scheduleIndex
        ];

        uint256 currentTime = block.timestamp;
        uint256 cliffEndTime = schedule.startTime + schedule.cliffDuration;
        uint256 vestingEndTime = schedule.startTime + schedule.vestingDuration;

        if (currentTime < cliffEndTime) {
            return 0;
        } else {
            // completely vested
            if (currentTime >= vestingEndTime) {
                return schedule.totalOptions;
            }

            uint256 vestedDuration = currentTime - cliffEndTime;
            uint256 totalVestingDuration = schedule.vestingDuration -
                schedule.cliffDuration;

            return
                ((vestedDuration * schedule.totalOptions) /
                    totalVestingDuration) - schedule.exercisedOptions;
        }
    }
    // *todo end
}
