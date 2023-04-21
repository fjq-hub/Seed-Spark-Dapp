pragma solidity ^0.8.0;
import "./ERC20.sol";

contract SeedToken {

    ERC20 erc20Contract;
    
    constructor() public {
        erc20Contract = new ERC20();
    }

    function _mint() public payable{
        uint256 amount = msg.value/(10**16);
        erc20Contract.mint(msg.sender, amount);
    }

    function getBalance(address _address) public view returns (uint256){
        return erc20Contract.balanceOf(_address);
    }

    function getTotalSupply() public view returns(uint256){
        return erc20Contract.totalSupply();
    }

    function _transfer(address _to, uint256 _value) public returns (bool) {
        return erc20Contract.transfer(_to, _value);
    }
    
    function _transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        return erc20Contract.transferFrom(_from, _to, _value);
    }

    function _approve(address _spender, uint256 _value) public returns (bool){
        return erc20Contract.approve(_spender, _value);
    }

    function _allowance(address _owner, address _spender) public view returns (uint256){
        return erc20Contract.allowance(_owner, _spender);
    }

}