# uniswapV3
uniswapV3源码分析，参考https://liaoph.com/    大佬的博客

# 创建交易对

首先在前端界面，（v3-core合约更新略有调整）用户调用PoolInitializer.sol合约的createAndInitializePoolIfNecessary方法创建交易对，传入的参数为交易对的 token0, token1, fee 和初始价格 (根号)√p，

createAndInitializePoolIfNecessary方法中，调用UniswapV3Factory的createPool方法完成交易对的创建，然后对交易对进行初始化，初始化的作用就是给交易对设置一个初始的价格。

调用过程：createAndInitializePoolIfNecessary ==> UniswapV3Factory.createPool ==> deploy 

# CREATE2

创建交易对，就是创建一个新的合约，作为流动池来提供交易功能。创建合约的步骤是：
<code>
    pool = address(new UniswapV3Pool{salt: keccak256(abi.encode(token0, token1, fee))}());
</code>
这里先通过 keccak256(abi.encode(token0, token1, fee) 将 token0, token1, fee 作为输入，得到一个哈希值，并将其作为 salt 来创建合约。因为指定了 salt, solidity 会使用 EVM 的 CREATE2 指令来创建合约。使用 CREATE2 指令的好处是，只要合约的 bytecode 及 salt 不变，那么创建出来的地址也将不变。

# 提供流动性

在合约内，v3 会保存所有用户的流动性，代码内称作 Position.

用户还是首先和 NonfungiblePositionManager 合约交互.v3 这次将 LP token 改成了 ERC721 token，并且将 token 功能放到 NonfungiblePositionManager 合约中。这个合约替代用户完成提供流动性操作，然后根据将流动性的数据元记录下来，并给用户铸造一个 NFT Token.

# postion 更新
接着我们看 UniswapV3Pool 是如何添加流动性的。流动性的添加主要在 UniswapV3Pool._modifyPosition 中，这个函会先调用 _updatePosition 来创建或修改一个用户的 Position.
Postion 是以 owner, lower tick, uppper tick 作为键来存储的，注意这里的 owner 实际上是 NonfungiblePositionManager 合约的地址。这样当多个用户在同一个价格区间提供流动性时，在底层的 UniswapV3Pool 合约中会将他们合并存储。而在 NonfungiblePositionManager 合约中会按用户来区别每个用户拥有的 Position.

# tick 管理

我们再来看 tick 相关的管理，在 UniswapV3Pool 合约中有两个状态变量记录了 tick 相关的信息ticks、tickBitmap。（查看合约UniswapV3Pool，库 Tick ）

# 完成流动性添加

_modifyPosition 调用完成后，会返回 x token, 和 y token 的数量。再来看 UniswapV3Pool.mint 的代码,这个函数关键的步骤就是通过回调函数，让调用方发送指定数量的 x token 和 y token 至合约中。

我们再来看 NonfungiblePositionManager.mint 的代码,可以看到这个函数主要是将用户的 Position 保存起来，并给用户铸造 NFT token，代表其所持有的流动性。至此提供流动性的步骤就完成了。

# 流动性的移除

移除流动性就是上述操作的逆操作，看 UniswapV3Pool.burn 代码，移除流动性时，还是使用之前的公式计算出移出的 token 数，但是并不会直接将移出的 token 数发送给用户，而是记录在了 position 的 tokensOwed0 和 tokensOwed1 上。这样做应该是为了遵循实践：Favor pull over push for external calls. 再看NonfungiblePositionManager.burn代码。