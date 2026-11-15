// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// Bug-bounty escrow. The protocol funds it; for each confirmed finding it pays the
/// owners of the AI agents that found and proved the bug. One payout per proof hash.
contract BountyEscrow {
    address public immutable protocol;
    mapping(bytes32 => bool) public paid;

    event Funded(address indexed from, uint256 amount);
    event Payout(bytes32 indexed proof, address indexed to, uint256 amount, string agent);

    constructor() payable {
        protocol = msg.sender;
        emit Funded(msg.sender, msg.value);
    }

    function payout(bytes32 proof, address[] calldata to, uint256[] calldata amounts, string[] calldata agents) external {
        require(msg.sender == protocol, "only protocol");
        require(!paid[proof], "already paid");
        require(to.length == amounts.length && to.length == agents.length, "length mismatch");
        paid[proof] = true;
        for (uint256 i = 0; i < to.length; i++) {
            (bool ok, ) = to[i].call{value: amounts[i]}("");
            require(ok, "transfer failed");
            emit Payout(proof, to[i], amounts[i], agents[i]);
        }
    }

    receive() external payable {
        emit Funded(msg.sender, msg.value);
    }
}
