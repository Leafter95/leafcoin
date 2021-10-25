// SPDX-License-Identifier: UNLICENSED
/// @author Leafter team 

pragma solidity ^0.8.1;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";


/**
 * @dev This contract is the core of Leafter :
 * Factory Setup is called for each affiliate product
 * Peasents brings material to cooperatives. That grants factory allowance to mint tokens
 * Factory production => Mint tokens
 * Dispatch to peasants on a pull pattern basin (shares = brings)
 * Dispatch can be paused
 * 
 * IMPORTANT : The contract must be granted a MINTER Role by the token grantRole  = 0x9F2DF0FED2C77648DE5860A4CC508CD0818C85B8B8A1AB4CEEEF8D981C8956A6
 */
contract LeafcoinFactory is Ownable   {
 
    
    ERC20PresetMinterPauser private _token;
  
    
    struct Cooperative {
        uint256 stock;          // incremented when peasant brings material, decremented when minted
        uint256 totalBring;     // incremented when peasant brings material, decremented when release  to peasant occures (used for shares)
        uint256 totalMint;      // incremented for each product mint
        uint256 credit;         // incremented for each product mint event according to cooperative shares in factory
        bool    releasePaused;  // Release can be paused to wait for full season brings (fair shares between peasants)

    }
    
    struct Factory {
        uint256 totalShares;
        uint256 clientShares;   // client shares is fixed but cannot be passed inside array
        address[] payees;       // cooperative is one of the payees
        uint256[] shares;
        uint256[] requires;     // Necessary quantity per Leafcoin minted ( if >0 => coopérative)
    }
    
    /// Map des factories (1 factory par produis labellisé)
    mapping(address => Factory) public factories;
    
    /// Map des coopératives (1 factory peut dépendre de plusieurs coopératives, 1 coopérative peut addresser plusieurs factory)
    mapping(address => Cooperative) public cooperatives;
    
    /// Map des apports par factory / par coopérative / par paysan
    mapping(address => mapping(address => mapping(address => uint256 ))) public brings;
    

    //--------------------------------------------------------------------------
    constructor ( ERC20PresetMinterPauser token ) {
         _token = token;
    }
    
    
     /*
     * @dev Add a new factory product chain. (1 eth adress /product)
     * @param _factory The eth address of the factory (a simple key for storage, no manipulation neither lfc nor eth are send)
     * @param _payees Array of payee eth adressess
     * @param _shares Array of shares (same size)
     * @param _requires Array of material required per leafcoin unit (same size)
     * @param _clientShares specifies client shares (address may vary for each product sell that triggers the mint trtansaction)
     */
    function setupFactory (address _factory, address[] memory _payees, uint256[] memory _shares, uint256[] memory _requires, uint256 _clientShares)  public onlyOwner
    {
        require(_factory != address(0), "setupFactory: null factory address");
        require(_payees.length == _shares.length, "setupFactory: payees and shares length mismatch");
        require(_shares.length == _requires.length, "setupFactory: shares and requires length mismatch");
        require(_payees.length > 0, "setupFactory: no payees");
    
           
        // Init factory 
        factories[_factory].totalShares = 0;
        factories[_factory].payees = _payees; 
        factories[_factory].shares = _shares; 
        factories[_factory].requires = _requires; 
        
       // factories[_factory].allowance = 0;
        
        for (uint256 i = 0; i < _payees.length; i++) 
        {
            factories[_factory].totalShares += _shares[i];
        }
        
       
        factories[_factory].totalShares += _clientShares;
        factories[_factory].clientShares = _clientShares;  // CLient shares stores separatly 
       
    }
    
    
     /*
     * @dev Credit factory account with some CO2 sequestrated by delivered material (straw...)
     * @param _peasant The eth address of the peasant 
     * @param _cooperative The eth address of the cooperative 
     * @param _factory The eth address of the factory 
     * @param _qty quantiti of bring material of this delivery (in grams)
     */
    function bringMaterial (address _peasant, address _cooperative, address _factory, uint256 _qty)  public onlyOwner
    {
       
        require(factories[_factory].totalShares > 0, "livraisonMatiere: unknown factory");
        require(_peasant != address(0), "livraisonMatiere: invalid peasant address");
        require(_cooperative != address(0), "livraisonMatiere: invalid cooperative address");
        require(_factory != address(0), "livraisonMatiere: invalid factory address");
        require(_qty > 0, "livraisonMatiere: amount = 0");
           
        // Increment peasant share for this factory+cooperative
        brings[_factory][_cooperative][_peasant] += _qty;
  
        // Increment total Share of all peasant for this cooperative
        cooperatives[_cooperative].totalBring += _qty;
        
        // Increment the stock of the cooperative
        cooperatives[_cooperative].stock += _qty;
       
       
    }
    
     /**
     * @dev Triggers a transfer to factory accounts of the amount of LFC they are owed, according to their shares defined by setupFactory
     * Client address might be left to 0, thus transfering leafcoins to owner (for R&D purpose)
     * @param _factory sharesThe eth address of the factory (a simple key for storage, no manipulation)
     * @param _amount amount of leacoin to generate for this trtansaction
     * @param _client client shares will be credited with factory defined _clientShared (can be left to 0)
     */
    function mymint(address _factory, uint256 _amount, address _client) public onlyOwner
    {
        require(factories[_factory].totalShares > 0, "mymint: account is not a factory");
        require(_amount > 0, "mymint: amount is NULL");
       // require(factories[_factory].allowance >= _amount, "mymint: insuffisant raw material delivered");
        
         // decrease allowance (consumed raw material for product)
       // factories[_factory].allowance -= _amount;
        
        // Get factory
        Factory memory factory = factories[_factory];
        
        // For each payee of the factory contract mint leafcoins according to shares defined in contract setup
        for (uint i = 0; i < factories[_factory].payees.length; i++) 
        {
            
            // Amount to mint for each payee
            uint256 amountTo = _amount * factory.shares[i] / factory.totalShares;

            // Si c'est une cooperative, on la crédite ici, les paysans seront mine sur dispatchToPeasants 
            if (factory.requires[i] > 0)
            {
                // If only one cooperative fails, whole transaction fails 
                uint256 requiredQty = factory.requires[i] *_amount;
                Cooperative storage cooperative  = cooperatives[factory.payees[i]];
                
                require (  cooperative.stock >= requiredQty, "mymint: cooperative insuffisant stock" );
                
                cooperative.credit += amountTo;
                cooperative.stock -= requiredQty;
            }
               
            // Sinon, on mine directement dans le portefeuille du beneficiaire
            else
                _token.mint(factory.payees[i], amountTo);
            
        }
        
        // The client shares minted in given address (can be R&D address)
        uint256 clientAmount = _amount * factory.clientShares / factory.totalShares ;
        if (_client != address(0))
            _token.mint( _client, clientAmount);
    }
    
    
  
   /*
     * @dev Pause paysant release 
     * @param _cooperative The eth address of the cooperative
     * @param _pause When true, peasant cannot release cooperative credit
     */
    function setReleasePaused(address _cooperative, bool _paused) public onlyOwner
    {
        cooperatives[_cooperative].releasePaused = _paused;
    }
    
     /*
     * @dev Dispatch cooperative credits to material bringers
     * @param _cooperative The eth address of the cooperative 
     */
    function releaseToPeasant(address _factory, address _cooperative, address _peasant, uint256 _amount) public onlyOwner
    {
       
        // Note : this method must be called while release is enabled : at the end of the season when every peasan has finish to bring materials
        require(_peasant != address(0), "releaseToPeasants: invalid peasant address");
        require(_amount > 0, "releaseToPeasants: amount is zero");
        require(brings[_factory][_cooperative][_peasant] > 0, "releaseToPeasants: peasant stock bring to cooperative is zero");
        require(cooperatives[_cooperative].credit >= _amount, "dispatchToPeasants: insufficient cooperative credit");
        require(cooperatives[_cooperative].releasePaused == false, "dispatchToPeasants: release is paused");
        
        uint256 credit = cooperatives[_cooperative].credit;
        require(credit > 0,"dispatchToPeasants: cooperative balance = 0" );
      
     
        uint256 peasantBrings = brings[_factory][_cooperative][_peasant];
        uint256 balance = credit * peasantBrings / cooperatives[_cooperative].totalBring;
        require(_amount <= balance ,"releaseToPeasant: insuffisant balance" );
         
        uint256 usedMaterial = _amount * peasantBrings / balance; 
      
        
        brings[_factory][_cooperative][_peasant] -= usedMaterial;
        cooperatives[_cooperative].totalBring -= usedMaterial;
        cooperatives[_cooperative].credit -= _amount;
        cooperatives[_cooperative].totalMint += _amount;
        /// Mint directly in peasant wallets
        _token.mint(_peasant, _amount );
            
   
        
        
    }
}