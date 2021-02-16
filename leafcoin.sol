pragma solidity ^0.8.1;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/presets/ERC20PresetMinterPauser.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Leafcoin is ERC20PresetMinterPauser, Ownable   {
 
   
    
    struct Factory {
        uint _totalShares;
        address[] payees;
        uint256[] shares;

    }
    
    
    mapping(address => Factory) public factories;
    
    constructor () public ERC20PresetMinterPauser ("Leafcoin", "LFC") {
      //  _mint(msg.sender, 1000000 * (10 ** uint256(decimals())));
    }
    
    
     /*
     * @dev Add a new factory product chain. (1 eth adress /product)
     * @param factoryAddress The eth address of the factory
     * @param payees Array of payee eth adressess
     * @param shares Array of shares (same size)
     */
    function setupFactory (address _address, address[] memory _payees, uint256[] memory _shares)  public onlyOwner
    {
       
        require(_payees.length == _shares.length, "setupFactory: payees and shares length mismatch");
        require(_payees.length > 0, "setupFactory: no payees");
    
           
       // factories[_address].payees = new Payee[](_payees.length); //= Filliere( new Payee[](_payees.length), 0);
        factories[_address]._totalShares = 0;
        factories[_address].payees = _payees; 
        factories[_address].shares = _shares; 
        
        for (uint256 i = 0; i < _payees.length; i++) 
        {
            factories[_address]._totalShares += _shares[i];
        }
        
       
    }
    
    
     /**
     * @dev Triggers a transfer to `account` of the amount of LFC they are owed, according to their percentage of the
     * total shares and their previous withdrawals.
     */
    function mymint(address _address, uint256 amount) public onlyOwner
    {
        require(factories[_address]._totalShares > 0, "mymint: account is not a factory");

        // Mine amount locally
         _mint(msg.sender, amount);
        
        // For each payee of the ffactory contract transfer leafcoins according to shares
        for (uint i = 0; i < factories[_address].payees.length; i++) 
        {
            uint256 amountTo = amount * factories[_address].shares[i] / factories[_address]._totalShares;
            transfer(factories[_address].payees[i], amountTo );
            
        }
    }
}