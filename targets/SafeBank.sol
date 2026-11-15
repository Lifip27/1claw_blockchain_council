// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// ETH bank using checks-effects-interactions. Intentionally safe (decoy).
contract SafeBank {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "insufficient");
        balances[msg.sender] -= amount;
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "send failed");
    }

    receive() external payable {}
}
