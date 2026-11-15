// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// ETH bank with deposits, withdrawals and internal transfers.
contract LockedBank {
    mapping(address => uint256) public balances;
    bool private locked;

    modifier lock() {
        require(!locked, "locked");
        locked = true;
        _;
        locked = false;
    }

    function deposit() external payable lock {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external lock {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "nothing to withdraw");
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "send failed");
        balances[msg.sender] = 0;
    }

    function transfer(address to, uint256 amount) external lock {
        require(balances[msg.sender] >= amount, "insufficient");
        balances[msg.sender] -= amount;
        balances[to] += amount;
    }

    receive() external payable {}
}
