// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract ROSCA {
    struct Group {
        string name;
        uint256 monthlyAmount;
        uint256 duration; // in months
        uint256 startTime;
        address[] members;
        mapping(address => bool) isMember;
        mapping(uint256 => address) monthlyWinner;
        mapping(address => bool) hasReceived;
        mapping(address => uint256) contributions;
        uint256 currentMonth;
        bool isActive;
        uint256 totalContributions;
    }

    struct Contribution {
        address member;
        uint256 groupId;
        uint256 amount;
        uint256 month;
        uint256 timestamp;
    }

    struct Payout {
        address winner;
        uint256 groupId;
        uint256 amount;
        uint256 month;
        uint256 timestamp;
    }

    mapping(uint256 => Group) public groups;
    uint256 public groupCounter;

    // Events
    event GroupCreated(uint256 indexed groupId, string name, uint256 monthlyAmount, uint256 duration, address creator);
    event MemberJoined(uint256 indexed groupId, address indexed member);
    event ContributionMade(uint256 indexed groupId, address indexed member, uint256 amount, uint256 month);
    event PayoutDistributed(uint256 indexed groupId, address indexed winner, uint256 amount, uint256 month);
    event GroupCompleted(uint256 indexed groupId);

    modifier onlyMember(uint256 groupId) {
        _onlyMember(groupId);
        _;
    }

    modifier groupExists(uint256 groupId) {
        _groupExists(groupId);
        _;
    }

    function _onlyMember(uint256 groupId) internal view {
        require(groups[groupId].isMember[msg.sender], "Not a member of this group");
    }

    function _groupExists(uint256 groupId) internal view {
        require(groupId < groupCounter, "Group does not exist");
    }

    function createGroup(string memory _name, uint256 _monthlyAmount, uint256 _duration) external returns (uint256) {
        require(_monthlyAmount > 0, "Monthly amount must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");
        require(bytes(_name).length > 0, "Group name cannot be empty");

        uint256 groupId = groupCounter++;
        Group storage newGroup = groups[groupId];

        newGroup.name = _name;
        newGroup.monthlyAmount = _monthlyAmount;
        newGroup.duration = _duration;
        newGroup.startTime = block.timestamp;
        newGroup.currentMonth = 0;
        newGroup.isActive = true;

        // Add creator as first member
        newGroup.members.push(msg.sender);
        newGroup.isMember[msg.sender] = true;

        emit GroupCreated(groupId, _name, _monthlyAmount, _duration, msg.sender);
        emit MemberJoined(groupId, msg.sender);

        return groupId;
    }

    function joinGroup(uint256 groupId) external payable groupExists(groupId) {
        Group storage group = groups[groupId];
        require(group.isActive, "Group is not active");
        require(!group.isMember[msg.sender], "Already a member");
        require(group.members.length < group.duration, "Group is full");

        group.members.push(msg.sender);
        group.isMember[msg.sender] = true;

        emit MemberJoined(groupId, msg.sender);
    }

    function contribute(uint256 groupId) external payable onlyMember(groupId) groupExists(groupId) {
        Group storage group = groups[groupId];
        require(group.isActive, "Group is not active");
        require(msg.value == group.monthlyAmount, "Incorrect contribution amount");

        uint256 currentMonth = getCurrentMonth(groupId);
        require(currentMonth < group.duration, "Group has ended");

        group.contributions[msg.sender] += msg.value;
        group.totalContributions += msg.value;

        emit ContributionMade(groupId, msg.sender, msg.value, currentMonth);

        // Check if all members have contributed for this month
        if (canDistributePayout(groupId, currentMonth)) {
            distributePayout(groupId, currentMonth);
        }
    }

    function distributePayout(uint256 groupId, uint256 month) internal {
        Group storage group = groups[groupId];

        // Simple winner selection (in production, this would use a more sophisticated method)
        address winner = selectWinner(groupId, month);
        require(winner != address(0), "No valid winner found");

        uint256 payoutAmount = group.monthlyAmount * group.members.length;
        group.monthlyWinner[month] = winner;
        group.hasReceived[winner] = true;

        // Transfer payout to winner (use call to allow forwarding gas)
        (bool sent, ) = payable(winner).call{value: payoutAmount}("");
        require(sent, "Payout transfer failed");
        group.currentMonth++;

        emit PayoutDistributed(groupId, winner, payoutAmount, month);

        // Check if group is completed
        if (month + 1 >= group.duration) {
            group.isActive = false;
            emit GroupCompleted(groupId);
        }
    }

    function selectWinner(uint256 groupId, uint256 month) internal view returns (address) {
        Group storage group = groups[groupId];

        // Simple pseudo-random selection from members who haven't received payout
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, groupId, month)));

        address[] memory eligibleMembers = new address[](group.members.length);
        uint256 eligibleCount = 0;

        for (uint256 i = 0; i < group.members.length; i++) {
            if (!group.hasReceived[group.members[i]]) {
                eligibleMembers[eligibleCount] = group.members[i];
                eligibleCount++;
            }
        }

        if (eligibleCount == 0) return address(0);

        return eligibleMembers[seed % eligibleCount];
    }

    function canDistributePayout(uint256 groupId, uint256 month) internal view returns (bool) {
        Group storage group = groups[groupId];

        // Check if all members have contributed the required amount
        uint256 expectedTotal = group.monthlyAmount * group.members.length * (month + 1);
        return group.totalContributions >= expectedTotal;
    }

    function getCurrentMonth(uint256 groupId) public view returns (uint256) {
        Group storage group = groups[groupId];
        if (!group.isActive) return group.duration;

        uint256 elapsed = block.timestamp - group.startTime;
        return elapsed / 30 days; // Simplified: 30 days per month
    }

    // View functions
    function getGroupInfo(uint256 groupId)
        external
        view
        groupExists(groupId)
        returns (
            string memory name,
            uint256 monthlyAmount,
            uint256 duration,
            uint256 startTime,
            uint256 memberCount,
            uint256 currentMonth,
            bool isActive,
            uint256 totalContributions
        )
    {
        Group storage group = groups[groupId];
        return (
            group.name,
            group.monthlyAmount,
            group.duration,
            group.startTime,
            group.members.length,
            group.currentMonth,
            group.isActive,
            group.totalContributions
        );
    }

    function getGroupMembers(uint256 groupId) external view groupExists(groupId) returns (address[] memory) {
        return groups[groupId].members;
    }

    function getMemberContribution(uint256 groupId, address member)
        external
        view
        groupExists(groupId)
        returns (uint256)
    {
        return groups[groupId].contributions[member];
    }

    function getMonthlyWinner(uint256 groupId, uint256 month) external view groupExists(groupId) returns (address) {
        return groups[groupId].monthlyWinner[month];
    }

    function hasReceivedPayout(uint256 groupId, address member) external view groupExists(groupId) returns (bool) {
        return groups[groupId].hasReceived[member];
    }

    // Allow contract to receive plain ETH transfers (useful for seeding in demos)
    receive() external payable {}

    // Return the contract balance (useful for frontend display)
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // Return the list of monthly winners for a group (length = duration)
    function getPayoutWinners(uint256 groupId) external view groupExists(groupId) returns (address[] memory) {
        Group storage group = groups[groupId];
        uint256 len = group.duration;
        address[] memory winners = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            winners[i] = group.monthlyWinner[i];
        }
        return winners;
    }

    // Return members who are still eligible to receive a payout (haven't received yet)
    function getEligibleMembers(uint256 groupId) external view groupExists(groupId) returns (address[] memory) {
        Group storage group = groups[groupId];
        uint256 count = 0;
        for (uint256 i = 0; i < group.members.length; i++) {
            if (!group.hasReceived[group.members[i]]) {
                count++;
            }
        }

        address[] memory eligible = new address[](count);
        uint256 j = 0;
        for (uint256 i = 0; i < group.members.length; i++) {
            if (!group.hasReceived[group.members[i]]) {
                eligible[j] = group.members[i];
                j++;
            }
        }

        return eligible;
    }
}
