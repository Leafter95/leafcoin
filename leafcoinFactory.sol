// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.1;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";

contract LeafcoinFactory is Ownable   {
 
    ERC20PresetMinterPauser private _token;
  
    
    struct Cooperative {
        uint256 totalBring;
        uint256 totalMint;
        uint256 credit;    // incremented for each product mint event
        address[] peasants;
        //uint256[] brings;
        mapping(address => uint256) brings;  // incremented for each peasant delivery (in leafcoin)
 
    }
    
    struct Factory {
        uint256 totalShares;
        uint256 clientShares;
        address[] payees;     // cooperative is one of the payees
        uint256[] shares;
        uint256 allowance;    // incremented for each material delivery (in leafcoin)
 
    }
    
    
    mapping(address => Factory) public factories;
    mapping(address => Cooperative) public cooperatives;

    constructor ( ERC20PresetMinterPauser token ) {
         _token = token;
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
        factories[_address].allowance = 0;
        
        for (uint256 i = 0; i < _payees.length; i++) 
        {
            factories[_address].totalShares += _shares[i];
        }
        
        // La part du client est stockée
        factories[_address].totalShares += _clientShares;
        factories[_address].clientShares = _clientShares; 
       
    }
    
    
   // async function callTokenMint(address, _amount) {
//
   // 
   // await  _token.mint(msg.address, _amount); //myToken.mint("0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0", "100000000000000000000");
   // console.log("Minting complete");
//
   // 
   // }

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
        require(factories[_address].allowance >= _amount, "mymint: insuffisant raw material delivered");
        
         // decrease allowance (consumed raw material for product)
        factories[_address].allowance -= _amount;
        
        // Get factory
        Factory memory factory = factories[_address];
        
        // For each payee of the factory contract mint leafcoins according to shares
        for (uint i = 0; i < factories[_address].payees.length; i++) 
        {
            uint256 amountTo = _amount * factory.shares[i] / factory.totalShares;
            
            // Si c'est une cooperative, on mine sur le contrat (appel ultérieur à dispatchToPeasants )
            if (cooperatives[factory.payees[i]].totalBring > 0)
            {
              //  _dispatchToPeasants (factory.payees[i], amountTo, _amount );
              
               cooperatives[factory.payees[i]].credit += amountTo;
               cooperatives[factory.payees[i]].totalMint += _amount;
            }
               
            // Sinon, on mine directement dans le portefeuille du beneficiaire
            else
                _token.mint(factory.payees[i], amountTo);
            
        }
        
        // The client shares minted in given address (can be R&D address)
        uint256 clientAmount = _amount * factories[_address].clientShares / factories[_address].totalShares ;
        if (_client != address(0))
            _token.mint( _client, clientAmount);
    }
    
    
      /*
     * @dev Credit factory account with some CO2 sequestrated by delivered material (straw...)
     * @param _peasant The eth address of the peasant 
     * @param _cooperative The eth address of the cooperative 
     * @param _factory The eth address of the factory 
     * @param _amount amount of leafcoin mint allowance thanks to this delivery (representing  sequestrated carbon inside factory)
     */
    function bringMaterial (address _peasant, address _cooperative, address _factory, uint256 _amount)  public onlyOwner
    {
       
        require(factories[_factory].totalShares > 0, "livraisonMatiere: unknown factory");
        require(_peasant != address(0), "livraisonMatiere: invalid peasant address");
        require(_cooperative != address(0), "livraisonMatiere: invalid cooperative address");
        require(_amount > 0, "livraisonMatiere: amount = 0");
           
        // factories[_address].payees = new Payee[](_payees.length); //= Filliere( new Payee[](_payees.length), 0);
        cooperatives[_cooperative].totalBring += _amount;
        if ( cooperatives[_cooperative].brings[_peasant] == 0 )
            cooperatives[_cooperative].peasants.push( _peasant);
        cooperatives[_cooperative].brings[_peasant] += _amount;
        factories[_factory].allowance += _amount;
       
       
    }
    
    
  
    
    /*
     * @dev Dispatch cooperative credits to material bringers
     * @param _cooperative The eth address of the cooperative 
     */
    function dispatchToPeasants (address _cooperative) public onlyOwner
    {
       
        
        require(_cooperative != address(0), "dispatchToPeasants: invalid cooperative address");
        require(cooperatives[_cooperative].totalBring > 0, "dispatchToPeasants: unknown cooperative");
        require(cooperatives[_cooperative].totalMint > 0, "dispatchToPeasants: unknown cooperative");
        
        uint256 credit = cooperatives[_cooperative].credit;
        require(credit > 0,"dispatchToPeasants: cooperative balance = 0" );
      //  require(_token.balanceOf(address(this)) > credit, "dispatchToPeasants: not enough token on contract for dispatch");
           
        // factories[_address].payees = new Payee[](_payees.length); //= Filliere( new Payee[](_payees.length), 0);
       // Cooperative storage cooperative = cooperatives[_cooperative];
       
       
         // For each payee of the cooperative contract transfer leafcoins according to shares
        for (uint i = 0; i < cooperatives[_cooperative].peasants.length; i++) 
        {
            address peasant = cooperatives[_cooperative].peasants[i];
            uint256 amountTo = credit * cooperatives[_cooperative].brings[peasant] / cooperatives[_cooperative].totalBring;
            uint256 used = cooperatives[_cooperative].brings[peasant] * cooperatives[_cooperative].totalMint / cooperatives[_cooperative].totalBring;
            
            cooperatives[_cooperative].brings[peasant] -= used;
          
            /// Minage dans le portefeuille des paysans
            _token.mint(cooperatives[_cooperative].peasants[i], amountTo );
            
        }
        cooperatives[_cooperative].credit = 0;
        cooperatives[_cooperative].totalBring -= cooperatives[_cooperative].totalMint;
        cooperatives[_cooperative].totalMint = 0;
        
    }
    
}