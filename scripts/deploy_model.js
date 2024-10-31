import { TurboFactory, ArweaveSigner } from '@ardrive/turbo-sdk';
import fs from "fs";
import path from 'path';
import Arweave from 'arweave';


// load Arweave wallet
const wallet = JSON.parse(
  fs.readFileSync(process.env.WALLET, 'utf-8')
);

const main = async () => {
  const signer = new ArweaveSigner(wallet);

  // 初始化 Arweave 客户端
  const arweave = Arweave.init({
    host: 'arweave.net',  // Arweave 主网
    port: 443,            // 默认 HTTPS 端口
    protocol: 'https',    // 使用 HTTPS 协议
  });
  // 获取钱包地址
  const address = await arweave.wallets.jwkToAddress(wallet);

  // 获取账户余额
  const balance = await arweave.wallets.getBalance(address);
  const arBalance1 = arweave.ar.winstonToAr(balance); // 将 winston 转换为 AR

  console.log(`账户地址: ${address}`);
  console.log(`账户余额: ${arBalance1} AR`);

  const turbo = TurboFactory.authenticated({ signer, arweave });


  // 获取账户余额
  const { winc } = await turbo.getBalance();
  const arBalance = winc / 1_000_000_000_000; // 将 winston 转换为 AR

  console.log(`账户余额: ${arBalance} AR`);
  // const _file = path.resolve('./test/process.wasm')

  // const receipt = await turbo.uploadFile({
  //   fileSizeFactory: () => fs.statSync(_file).size,
  //   fileStreamFactory: () => fs.createReadStream(_file),
  //   dataItemOpts: {
  //     tags: [
  //       { name: 'Content-Type', value: 'application/wasm' },
  //       { name: 'Data-Protocol', value: 'ao' },
  //       { name: 'Type', value: 'Module' },
  //       { name: 'Variant', value: 'ao.TN.1' },
  //       { name: 'Module-Format', value: 'wasm64-unknown-emscripten-draft_2024_02_15' },
  //       { name: 'Input-Encoding', value: 'JSON-1' },
  //       { name: 'Output-Encoding', value: 'JSON-1' },
  //       { name: 'Memory-Limit', value: '16-gb' },
  //       { name: 'Compute-Limit', value: '9000000000000' }
  //     ]
  //   }
  // });
  // console.log(receipt);
  // console.log('ModuleID: ', receipt.id)

  const data = fs.readFileSync('./test/process.wasm'); // 读取文件
  const transaction = await arweave.createTransaction({ data }, wallet);

  // 添加自定义标签
  transaction.addTag('Content-Type', 'application/octet-stream');
  transaction.addTag('Data-Protocol', 'Onchain-Llama');
  transaction.addTag('Type', 'Tokenizer');
  transaction.addTag('Model-Size', 0);
  transaction.addTag('Tokenizer-Size', 0);
  // { name: 'Next', value: previousId },


  // 签署并提交交易
  await arweave.transactions.sign(transaction, wallet);
  const response = await arweave.transactions.post(transaction);

  if (response.status === 200) {
    console.log(`文件上传成功，交易ID: ${transaction.id}`);
  } else {
    console.log(`文件上传失败，状态码: ${response.status}`);
  }
}

main()