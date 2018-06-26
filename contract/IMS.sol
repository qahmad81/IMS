pragma solidity ^0.4.24;

/// @title IMS Investor Management System
/// @author Ahmad Odeh
/// @notice invest shares system, share trade, Profits Distribution, Vote system

contract IMS {
  string public name = "Odeh IT";
  string public symbol = "ODH";
  uint8 public decimals = 8;
  uint256 totalSupply_ = 2000000 * 10 ** uint256(decimals);
  uint256 public minOffer = 1000 * 10 ** uint256(decimals);
  uint256 public minRemainder = 1 * 10 ** uint256(decimals);
  uint256 public priceDecimals = 10;  // 10 ** priceDecimals = wei

  mapping(address => uint256) balances;
  mapping(address => uint256) lockedBalances;
    
  address public owner;
  
  mapping(address => uint8) joiners;
  address[] members;

  struct Trade {
    address owner;
    uint8 way; // 1:sell 2:buy
    uint createTime;
    uint amount;
    uint price;
  }
  Trade[] public trades;
  mapping(address => uint[]) myTrade;

  
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }
  
  // This generates a public event on the blockchain that will notify clients
  event Transfer(address indexed from, address indexed to, uint256 value);

  // This notifies clients about the amount burnt
  event Burn(address indexed from, uint256 value);
  
  
  function setMinOffer(uint256 _minOffer) external onlyOwner  {
    minOffer = _minOffer;
  }
  
  function setMinRemainder(uint256 _minRemainder) external onlyOwner  {
    minRemainder = _minRemainder;
  }
  
  function setPriceDecimals(uint256 _priceDecimals) external onlyOwner  {
    priceDecimals = _priceDecimals;
  }
  
  function setName(string _name) external onlyOwner  {
    name = _name;
  }
  
  function setSymbol(string _symbol) external onlyOwner  {
    symbol = _symbol;
  }
  
  function tradeList(uint8 _way) external view returns (uint[], uint[]) {
    uint[] memory _tradeListPrice, _tradeListAmount;
    int i,j, temp, found, counter = 0;

    // make filtered array of sell prices or buy prices without repeating
    for(i=0;i <= trades.length;i++) {
      if (trades[i].way != _way) continue;
      found = 0;
      for(j=0;j <= _tradeListPrice.length;j++) {
        if (trades[i].price == _tradeListPrice[j]) {
          found = 1;
          break;
        }
      }
      if (found != 1) {
        _tradeListPrice[counter] = trades[i].price;
        counter++;
      }
    }

    // sort the new price array ASC with selling list, DESC with buying list
    _price = _tradeListPrice[0];
    for(i=0;i <= _tradeListPrice.length;i++) {
      for(j=0;j <= _tradeListPrice.length;j++) {
        if (_way == 1) {
          if (_tradeListPrice[i] > _tradeListPrice[j]) {
            temp = _tradeListPrice[j];
            _tradeListPrice[j] = _tradeListPrice[i];
            _tradeListPrice[i] = temp;
          }
        } else if (_way ==2) {
          if (_tradeListPrice[i] < _tradeListPrice[j]) {
            temp = _tradeListPrice[j];
            _tradeListPrice[j] = _tradeListPrice[i];
            _tradeListPrice[i] = temp;
          }
        }
      }
    }
    
    // make amount array
    for(i=0;i <= _tradeListPrice.length;i++) {
      for(j=0;j <= trades.length;j++) {
        if (trades[j].way != _way) continue;
        if (_tradeListPrice[i] == trades[j].price) {
          _tradeListAmount[i] += trades[j].amount;
        }
      }
    }
  }

  function tradeSearch(uint8 _way, uint _price) public returns (uint8 _found, uint _tradeId) {
    uint price = _price;
    uint _createTime = 0;
    uint8 found = 0;
    uint tradeId;
    for(uint i;i <= trades.length;i++) {
      if (trades[i].way == 1 && _way == 1) {
        if (trades[i].price <= price ) {
          if (_createTime == 0 || trades[i].createTime < _createTime ) {
            _createTime = trades[i].createTime;
            price = trades[i].price;
            found = 1;
          }
        }
      } else if (trades[i].way == 2 && _way == 2) {
        if (trades[i].price >= price) {
          if (_createTime == 0 || trades[i].createTime < _createTime ) {
            _createTime = trades[i].createTime;
            price = trades[i].price;
            found = 1;
          }
        }
      }
    }
    return (found, tradeId);
  }
  
  function makeSellTrade(uint256 _Amount, uint256 _price) external {
    uint256 _amount = _Amount;
    require(_amount >= minOffer);
    require(msg.value >= _amount);
    require(_price % 10 ** uint256(priceDecimals) == 0);
    uint _value = _amount * _price;
    uint8 _found = 1;
    uint _tradeId;
    
    while(_found == 1 && _amount >= minRemainder) {
      // search for highest oldest buy offer
      (_found, _tradeId) = tradeSearch(2, _price);
      if (_found == 1) {
        if (trades[_tradeId].amount == _amount) {
          balances[trades[_tradeId].owner] += _amount;
          msg.sender.transfer(_amount * trades[_tradeId].price);
          _removeTrade(_tradeId);
          _amount = 0;
        }
        if (trades[_tradeId].amount > _amount) {
          balances[trades[_tradeId].owner] += _amount;
          msg.sender.transfer(_amount * trades[_tradeId].price);
          trades[_tradeId].amount -= _amount;
          _amount = 0;
        }
        if (trades[_tradeId].amount < _amount) {
          balances[trades[_tradeId].owner] += trades[_tradeId].amount;
          msg.sender.transfer(trades[_tradeId].amount * trades[_tradeId].price);
          _removeTrade(_tradeId);
          _amount -= trades[_tradeId].amount;
        }
      }
    }
    
    if (_amount >= minRemainder) {
      balances[msg.sender] -= _value;
      lockedBalances[msg.sender] += _value;
      uint id = trades.push(Trade(msg.sender, 1, now, _amount, _price));
      myTrade[msg.sender].push(id);
    }
  }

  function makeBuyTrade(uint256 amount, uint256 _price) external payable {
    uint256 _amount = amount;
    require(_amount >= minOffer);
    require(msg.value >= _amount);
    require(_price % 10 ** uint256(priceDecimals) == 0);
    uint _value = _amount * _price;
    uint _tradeValue = 0;
    uint remainder;
    require(_value == msg.value);
    uint8 _found = 1;
    uint _tradeId;
    
    while(_found == 1 && _amount >= minRemainder) {
      // search for lowest oldest sale
      (_found, _tradeId) = tradeSearch(1, _price); 
      if (_found == 1) {
        if (trades[_tradeId].amount == _amount) {
          balances[msg.sender] += _amount;
          trades[_tradeId].owner.transfer(_amount * trades[_tradeId].price);
          _tradeValue += _amount * trades[_tradeId].price;
          _removeTrade(_tradeId);
          _amount = 0;
        }
        if (trades[_tradeId].amount > _amount) {
          balances[msg.sender] += _amount;
          trades[_tradeId].owner.transfer(_amount * trades[_tradeId].price);
          _tradeValue += _amount * trades[_tradeId].price;
          trades[_tradeId].amount -= _amount;
          _amount = 0;
        }
        if (trades[_tradeId].amount < _amount) {
          balances[msg.sender] += trades[_tradeId].amount;
          trades[_tradeId].owner.transfer(trades[_tradeId].amount * trades[_tradeId].price);
          _tradeValue += trades[_tradeId].amount * trades[_tradeId].price;
          _removeTrade(_tradeId);
          _amount -= trades[_tradeId].amount;
        }
      }

    }

    if (_amount >= minRemainder) {
      uint id = trades.push(Trade(msg.sender, 2, now, _amount, _price));
      myTrade[msg.sender].push(id);
      _tradeValue += _amount * _price;
      _amount = 0;
    }
    
    remainder = _value - _tradeValue;
    msg.sender.transfer(remainder);
  }
  
  function cancelTrade(uint _tradesId) external {
    Trade storage trade = trades[_tradesId];
    require(trade.owner == msg.sender);
    uint _value = trade.amount * trade.price;
    if (trade.way == 1) {
      balances[msg.sender] += _value;
      lockedBalances[msg.sender] -= _value;
      _removeTrade(_tradesId);
      
        
    } else if (trade.way == 2) {
      require(this.balance >= _value);
      trade.owner.transfer(_value);
      _removeTrade(_tradesId);

        
    }
  }
  
  function profitsDistribution(uint value, uint onvalue, uint minProfitBalance, uint minProfit) {
      uint theprofit = 0;
      uint balance;
      for (uint i = 0; i<members.length; i++){
        balance = balances[members[i]];
        require(balance>=minProfitBalance);
        theprofit = balance / 10 ** uint256(decimals) * value / onvalue;
        require(theprofit>=minProfit);
        members[i].transfer(theprofit);
      }
  }
  
  function _removeTrade(uint _tradesId) private {
    require(_tradesId < myTrade[msg.sender].length);
    
    for (uint i = _tradesId; i<trades.length-1; i++){
        trades[i] = trades[i+1];
    }
    trades.length--;
    
    uint sheft = 0;
    for (i = 0; i<myTrade[msg.sender].length-1; i++){
        if (myTrade[msg.sender][i] == _tradesId) sheft = 1;
        if (sheft == 1) myTrade[msg.sender][i] = myTrade[msg.sender][i+1];
    }
    myTrade[msg.sender].length--;
  }

  constructor() public {
    owner = msg.sender;
    balances[msg.sender] = totalSupply_;
    joiners[msg.sender] = 1;
    members.push(owner);
  }

  function totalSupply() public view returns (uint256) {
    return totalSupply_;
  }

  function activeTotalSupply() public view returns (uint256) {
    uint256 activeTotalSupply_ = 0;
    for (uint i = 0; i < members.length; i++) 
        if (members[i] != owner) activeTotalSupply_ += balances[members[i]];
    return ;
  }

  function balanceOf(address _owner) public view returns (uint256) {
    return balances[_owner];
  }
  
  function burn(uint256 _value) public onlyOwner returns (bool success) {
    _value = _value * 10 ** uint256(decimals);
    require(balances[msg.sender] >= _value);
    balances[msg.sender] -= _value;
    totalSupply_ -= _value; 
    emit Burn(msg.sender, _value);
    return true;
  }
  
  function _transfer(address _from, address _to, uint256 _value) internal {
    require(_to != 0x0);
    require(balances[_from] >= _value);
    require(balances[_to] + _value >= balances[_to]);
    uint previousBalances = balances[_from] + balances[_to];
    if (joiners[_to] >= 1) {
      joiners[_to] = 1;
      members.push(_to);
    }
    balances[_from] -= _value;
    balances[_to] += _value;
    emit Transfer(_from, _to, _value);
    assert(balances[_from] + balances[_to] == previousBalances);
  }

  function transfer(address _to, uint256 _value) public {
    _transfer(msg.sender, _to, _value);
  }
  
}
