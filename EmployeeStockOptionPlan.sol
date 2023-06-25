// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EmployeeStockOptionPlan {
    // *todo 1. Define the necessary data structures and variables
    // Structure to hold vesting schedule for an employeeAddress
    struct VestingSchedule {
        uint256 cliffDuration; // Cliff duration in seconds
        uint256 vestingDuration; // Total vesting duration in seconds
        uint256 startTime; // Start time of the vesting schedule
    }

    // Structure to hold information about an employeeAddress
    struct Employee {
        bool isActive; // Flag to indicate whether the employeeAddress is active
        uint256 grantedOptions; // Total number of stock options granted to the employeeAddress
        uint256 receivedOptions; // Total number of stock options received from other employees
        uint256 transferredOptions; // Total number of stock options transferred to other employees
        uint256 exercisedOptions; // Number of stock options exercised so far
        VestingSchedule vestingSchedule; // Options vesting schedule for the employeeAddress
    }

    address public owner; // Contract owner address

    mapping(address => Employee) public employees; // Mapping of employees by address

    // *todo end

    // *todo 2. Define the necessary events
    event StockOptionsGranted(
        address indexed employeeAddress,
        uint256 stockOptions
    );

    event VestingScheduleSet(
        address indexed employeeAddress,
        uint256 cliffDuration,
        uint256 vestingDuration
    );

    event StockOptionsExercised(
        address indexed employeeAddress,
        uint256 amount
    );

    event StockOptionsTransferred(
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
        address employeeAddress,
        uint256 stockOptions
    ) external onlyOwner {
        require(
            !employees[employeeAddress].isActive,
            "Options have already been granted to this employeeAddress."
        );

        require(stockOptions > 0, "Stock options must be greater than zero.");

        employees[employeeAddress].isActive = true;
        employees[employeeAddress].grantedOptions = stockOptions;

        emit StockOptionsGranted(employeeAddress, stockOptions);
    }

    // *todo end

    // *todo 5. Implement the functions for setting the vesting schedule
    function setVestingSchedule(
        address employeeAddress,
        uint256 cliffDuration,
        uint256 vestingDuration
    ) external onlyOwner onlyActiveEmployee(employeeAddress) {
        require(
            employees[employeeAddress].vestingSchedule.startTime == 0,
            "Vesting schedule has already been set"
        );

        require(cliffDuration > 0, "cliff duration must be greater than zero.");

        require(
            vestingDuration > 0,
            "vesting duration must be greater than zero."
        );

        employees[employeeAddress].vestingSchedule = VestingSchedule(
            cliffDuration,
            vestingDuration,
            block.timestamp
        );

        emit VestingScheduleSet(
            employeeAddress,
            cliffDuration,
            vestingDuration
        );
    }

    // *todo end

    // *todo 6. Implement the functions for exercising stock options
    function exerciseOptions(
        uint256 amount
    )
        external
        onlyActiveEmployee(msg.sender)
        hasAvailableOptions(msg.sender, amount)
    {
        require(amount > 0, "Amount must be greater than zero.");

        uint256 exercisedOptions = employees[msg.sender].exercisedOptions;
        employees[msg.sender].exercisedOptions = exercisedOptions + amount;

        emit StockOptionsExercised(msg.sender, amount);
    }

    // *todo end

    // *todo 7. Implement the functions for tracking vested and exercised stock options
    function getVestedOptions(
        address employeeAddress
    ) public view onlyActiveEmployee(employeeAddress) returns (uint256) {
        VestingSchedule memory schedule = employees[employeeAddress]
            .vestingSchedule;

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
                return employees[employeeAddress].grantedOptions;
            }

            uint256 vestedDuration = currentTime - cliffEndTime;
            uint256 totalVestingDuration = schedule.vestingDuration -
                schedule.cliffDuration;

            return ((vestedDuration *
                employees[employeeAddress].grantedOptions) /
                totalVestingDuration);
        }
    }

    function getExercisedOptions(
        address employeeAddress
    ) public view onlyActiveEmployee(employeeAddress) returns (uint256) {
        return employees[employeeAddress].exercisedOptions;
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

    modifier onlyActiveEmployee(address employeeAddress) {
        require(
            employees[employeeAddress].isActive,
            "The employeeAddress is not active."
        );
        _;
    }

    modifier hasAvailableOptions(address employeeAddress, uint256 amount) {
        require(
            amount <= getAvailableOptions(employeeAddress),
            "Insufficient vested stock options available for exercise."
        );
        _;
    }

    modifier vestingScheduleCompleted(address employeeAddress) {
        require(
            employees[employeeAddress].isActive,
            "The employeeAddress is not active."
        );

        VestingSchedule memory schedule = employees[employeeAddress]
            .vestingSchedule;
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
        require(amount > 0, "Amount must be greater than zero.");

        address from = msg.sender;

        employees[from].transferredOptions += amount;

        employees[to].receivedOptions += amount;

        emit StockOptionsTransferred(from, to, amount);
    }

    function getTotalOptions(
        address employeeAddress
    ) public view onlyActiveEmployee(employeeAddress) returns (uint256) {
        return
            getVestedOptions(employeeAddress) +
            employees[employeeAddress].receivedOptions;
    }

    function getAvailableOptions(
        address employeeAddress
    ) public view onlyActiveEmployee(employeeAddress) returns (uint256) {
        Employee memory employee = employees[employeeAddress];

        return
            (getVestedOptions(employeeAddress) + employee.receivedOptions) -
            (employee.exercisedOptions + employee.transferredOptions);
    }

    // *todo end
}
