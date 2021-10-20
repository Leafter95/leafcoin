// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.1;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/presets/ERC20PresetMinterPauser.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Leafcoin is ERC20PresetMinterPauser, Ownable   {
 
    struct Cooperative {
        uint totalBring;
        mapping(address => uint256) public brings;  // incremented for each peasant delivery (in leafcoin)
 
    }
    
    struct Factory {
        uint totalShares;
        uint clientShares;
        address[] payees;
        uint256[] shares;
        uint256 allowance;    // incremented for each material delivery (in leafcoin)
 
    }
    
    
    mapping(address => Factory) public factories;
    mapping(address => Cooperative) public Cooperatives;

    constructor () ERC20PresetMinterPauser ("Leafcoin", "LFC") {
        // By construction, there is initially ZERO leafcoins minted
    }
    
    
     /*
     * @dev Add a new factory product chain. (1 eth adress /product)
     * @param _address The eth address of the factory (a simple key for storage, no manipulation neither lfc nor eth are send)
     * @param _payees Array of payee eth adressess
     * @param _shares Array of shares (same size)
     * @param _clientShares specifies client shares (address may vary for each product sell that triggers the mint trtansaction)
     */
    function setupFactory (address _address, address[] memory _payees, uint256[] memory _shares, uint256 _clientShares)  public onlyOwner
    {
       
        require(_payees.length == _shares.length, "setupFactory: payees and shares length mismatch");
        require(_payees.length > 0, "setupFactory: no payees");
    
           
       // factories[_address].payees = new Payee[](_payees.length); //= Filliere( new Payee[](_payees.length), 0);
        factories[_address].totalShares = 0;
        factories[_address].payees = _payees; 
        factories[_address].shares = _shares; 
        
        for (uint256 i = 0; i < _payees.length; i++) 
        {
            factories[_address].totalShares += _shares[i];
        }
        
        // La part du client est stockée
        factories[_address].totalShares += _clientShares;
        factories[_address].clientShares = _clientShares; 
       
    }
    
    
     /**
     * @dev Triggers a transfer to factory accounts of the amount of LFC they are owed, according to their shares defined by setupFactory
     * Client address might be left to 0, thus transfering leafcoins to owner (for R&D purpose)
     * @param _address sharesThe eth address of the factory (a simple key for storage, no manipulation)
     * @param _amount amount of leacoin to generate for this trtansaction
     * @param _client client shares will be credited with factory defined _clientShared (can be left to 0)
     */
    function mymint(address _address, uint256 _amount, address _client) public onlyOwner
    {
        require(factories[_address].totalShares > 0, "mymint: account is not a factory");
        require(_amount > 0, "mymint: amount is NULL");
        require(factories[_address].allowance > _amount, "mymint: insuffisant raw material delivered");
        
         // decrease allowance (consumed raw material for product)
        factories[_address].allowance -= _amount;
        
        // Mine amount locally
        _mint(msg.sender, _amount);
        
        Factory memory factory = factories[_address];
        
        // For each payee of the factory contract transfer leafcoins according to shares
        for (uint i = 0; i < factories[_address].payees.length; i++) 
        {
            uint256 amountTo = _amount * factory.shares[i] / factory.totalShares;
            transfer(factory.payees[i], amountTo );
            
        }
        
        // The client shares are transfered id address specified; if not leave leafcoins on owner address
        uint256 clientAmount = _amount * factories[_address].clientShares / factories[_address].totalShares ;
        if (_client != address(0))
            transfer(_client, clientAmount);
    }
    
      /*
     * @dev Credit factory account with some CO2 sequestrated by delivered material (straw...)
     * @param _address The eth address of the factory 
     * @param _amount amount of leafcoin mint allowance thanks to this delivery (representing  sequestrated carbon inside factory)
     */
    function bringMaterial (address _peasant, address _cooperative, address _factory, uint256 _amount)  public onlyOwner
    {
       
        require(factories[_factory].totalShares > 0, "livraisonMatiere: unknown factory");
        require(_peasant != address(0), "livraisonMatiere: invalid peasant address");
        require(_cooperative != address(0), "livraisonMatiere: invalid cooperative address");
        require(_amount > 0, "livraisonMatiere: amount = 0");
           
        // factories[_address].payees = new Payee[](_payees.length); //= Filliere( new Payee[](_payees.length), 0);
        Cooperatives[_cooperative].totalShares += _amount;
        Cooperatives[_cooperative].brings[_peasant] += _amount;
        factories[_address].allowance += _amount;
       
       
    }
    
    /*
     * @dev Credit factory account with some CO2 sequestrated by delivered material (straw, wood...)
     * @param _address The eth address of the factory 
     * @param _amount amount of leafcoin mint allowance thanks to this delivery (representing  sequestrated carbon inside factory)
     */
    function dispatchToPeasants (address _cooperative)  public onlyOwner
    {
       
        
        require(_cooperative != address(0), "dispatchToPeasants: invalid cooperative address");
        require(cooperatives[_cooperative].totalBring > 0, "dispatchToPeasants: unknown cooperative");
        require(_amount > 0, "livraisonMatiere: amount = 0");
           
        // factories[_address].payees = new Payee[](_payees.length); //= Filliere( new Payee[](_payees.length), 0);
        Cooperative memory cooperative = cooperatives[_cooperative];
       
        
    }
    
}