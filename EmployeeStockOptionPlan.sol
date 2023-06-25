// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EmployeeStockOptionPlan {
    // *todo 1. Define the necessary data structures and variables
    // Structure to hold vesting schedule for an employee
    struct VestingSchedule {
        uint256 cliffDuration; // Cliff duration in seconds
        uint256 vestingDuration; // Total vesting duration in seconds
        uint256 startTime; // Start time of the vesting schedule
    }

    // Structure to hold information about an employee
    struct Employee {
        bool isActive; // Flag to indicate whether the employee is active
        uint256 totalOptions; // Total number of options granted to the employee
        uint256 exercisedOptions; // Number of options exercised so far
        VestingSchedule vestingSchedule; // Options vesting schedule for the employee
    }

    address public owner; // Contract owner address

    mapping(address => Employee) public employees; // Mapping of employees by address

    // *todo end

    // *todo 2. Define the necessary events
    event StockOptionsGranted(address indexed employee, uint256 options);

    event VestingScheduleSet(
        address indexed employee,
        uint256 cliffDuration,
        uint256 vestingDuration
    );

    event OptionsExercised(address indexed employee, uint256 amount);

    event OptionsTransferred(
        address indexed from,
        address indexed to,
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
        employees[employee].totalOptions = options;

        emit StockOptionsGranted(employee, options);
    }

    // *todo end

    // *todo 5. Implement the functions for setting the vesting schedule
    function setVestingSchedule(
        address employee,
        uint256 cliffDuration,
        uint256 vestingDuration
    ) external onlyOwner onlyActiveEmployee(employee) {
        require(
            employees[employee].vestingSchedule.startTime == 0,
            "Vesting schedule has already been set"
        );

        employees[employee].vestingSchedule = VestingSchedule(
            cliffDuration,
            vestingDuration,
            block.timestamp
        );

        emit VestingScheduleSet(employee, cliffDuration, vestingDuration);
    }

    // *todo end

    // *todo 6. Implement the functions for exercising options
    function exerciseOptions(
        uint256 amount
    )
        external
        onlyActiveEmployee(msg.sender)
        hasAvailableOptions(msg.sender, amount)
    {
        uint256 exercisedOptions = employees[msg.sender].exercisedOptions;
        employees[msg.sender].exercisedOptions = exercisedOptions + amount;

        emit OptionsExercised(msg.sender, amount);
    }

    // *todo end

    // *todo 7. Implement the functions for tracking vested and exercised options
    function getVestedOptions(
        address employee
    ) public view onlyActiveEmployee(employee) returns (uint256) {
        VestingSchedule memory schedule = employees[employee].vestingSchedule;

        if (schedule.startTime == 0) {
            return 0;
        }

        uint256 currentTime = block.timestamp;
        uint256 cliffEndTime = schedule.startTime + schedule.cliffDuration;
        uint256 vestingEndTime = schedule.startTime + schedule.vestingDuration;

        if (currentTime < cliffEndTime) {
            return 0;
        } else {
            // completely vested
            if (currentTime >= vestingEndTime) {
                return employees[employee].totalOptions;
            }

            uint256 vestedDuration = currentTime - cliffEndTime;
            uint256 totalVestingDuration = schedule.vestingDuration -
                schedule.cliffDuration;

            return ((vestedDuration * employees[employee].totalOptions) /
                totalVestingDuration);
        }
    }

    function getExercisedOptions(
        address employee
    ) public view onlyActiveEmployee(employee) returns (uint256) {
        return employees[employee].exercisedOptions;
    }

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

    modifier hasAvailableOptions(address employee, uint256 amount) {
        require(
            amount <=
                (getVestedOptions(employee) -
                    employees[employee].exercisedOptions),
            "Insufficient vested options available for exercise."
        );
        _;
    }

    modifier vestingScheduleCompleted(address employee) {
        require(employees[employee].isActive, "The employee is not active.");

        VestingSchedule memory schedule = employees[employee].vestingSchedule;
        uint256 currentTime = block.timestamp;
        uint256 endTime = schedule.startTime + schedule.vestingDuration;

        require(currentTime >= endTime, "Vesting schedule is not completed.");
        _;
    }

    // *todo end

    // *todo 9. Add any additional functions or modifiers as needed
    function transferOptions(
        address to,
        uint256 amount
    )
        external
        onlyActiveEmployee(msg.sender)
        onlyActiveEmployee(to)
        vestingScheduleCompleted(msg.sender)
        hasAvailableOptions(msg.sender, amount)
    {
        address from = msg.sender;

        uint256 exercisedOptions = employees[from].exercisedOptions;

        employees[from].exercisedOptions = exercisedOptions + amount;

        employees[to].totalOptions += amount;

        emit OptionsTransferred(from, to, amount);
    }

    // *todo end
}
