// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import './PeripheryImmutableState.sol';
import '../interfaces/IPoolInitializer.sol';

/// @title Creates and initializes V3 Pools
abstract contract PoolInitializer is IPoolInitializer, PeripheryImmutableState {
    /// @inheritdoc IPoolInitializer
    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable override returns (address pool) {
        require(token0 < token1);
        //首先调用 UniswapV3Factory.getPool 方法获取pool地址
        pool = IUniswapV3Factory(factory).getPool(token0, token1, fee);
        //查看交易对是否已经创建
        if (pool == address(0)) {
            /**
                没创建调用createPool方法创建交易对，使用IUniswapV3Pool的initialize初始化交易对价格
            */
            pool = IUniswapV3Factory(factory).createPool(token0, token1, fee);
            IUniswapV3Pool(pool).initialize(sqrtPriceX96);
        } else {
            /**
                已经创建则取出价格
            */
            (uint160 sqrtPriceX96Existing, , , , , , ) = IUniswapV3Pool(pool).slot0();
            /**
            价格为0初始化价格
            */
            if (sqrtPriceX96Existing == 0) {
                IUniswapV3Pool(pool).initialize(sqrtPriceX96);
            }
        }
    }
}
