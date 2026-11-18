import os
import sys
import glob
import cv2
import torch
import numpy as np
from concurrent.futures import ThreadPoolExecutor
from basicsr.archs.rrdbnet_arch import RRDBNet
from realesrgan import RealESRGANer

def save_frame(output_path, img):
    cv2.imwrite(output_path, img)

def main():
    if len(sys.argv) < 4:
        print("Usage: python upscale_cuda.py <input_frames_dir> <output_dir> <scale>")
        sys.exit(1)

    input_dir = sys.argv[1]
    output_dir = sys.argv[2]
    scale = int(sys.argv[3])
    batch_size = 4  # Adjust to 4 or 8 depending on VRAM headroom (RTX 5090 handles 8 easily for 720p/1080p)

    os.makedirs(output_dir, exist_ok=True)

    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"--> Initialized PyTorch CUDA on: {torch.cuda.get_device_name(0)}")
    torch.backends.cudnn.benchmark = True
    if hasattr(torch, 'set_float32_matmul_precision'):
        torch.set_float32_matmul_precision('high')

    # Initialize model architecture and load weights
    model = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=23, num_grow_ch=32, scale=scale)
    upsampler = RealESRGANer(
        scale=scale,
        model_path='https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth',
        model=model,
        tile=0,
        tile_pad=10,
        pre_pad=0,
        half=True
    )

    image_paths = sorted(glob.glob(os.path.join(input_dir, '*.png')))
    if not image_paths:
        print(f"❌ Error: No frames found in {input_dir}")
        return

    total_frames = len(image_paths)
    print(f"🚀 Processing {total_frames} frames with Batched RTX 5090 Acceleration (Batch Size: {batch_size})...")

    # Move model to half precision if half=True
    if upsampler.device.type == 'cuda':
        upsampler.model.half()

    executor = ThreadPoolExecutor(max_workers=4)

    # Process in batches
    for i in range(0, total_frames, batch_size):
        batch_paths = image_paths[i:i + batch_size]
        batch_imgs = []
        batch_names = []

        for path in batch_paths:
            img = cv2.imread(path, cv2.IMREAD_UNCHANGED)
            if img is not None:
                batch_imgs.append(img)
                batch_names.append(os.path.basename(path))

        if not batch_imgs:
            continue

        try:
            # Preprocess batch into tensor stack
            # Real-ESRGAN expects float32/float16 normalized tensors
            tensor_list = []
            for img in batch_imgs:
                img_f = img.astype(np.float32) / 255.0
                if img_f.ndim == 2:
                    img_f = np.tile(img_f[:, :, None], (1, 1, 3))
                # HWC to CHW
                img_t = torch.from_numpy(np.transpose(img_f, (2, 0, 1))).float()
                tensor_list.append(img_t)

            # Stack into batch tensor [B, C, H, W]
            batch_tensor = torch.stack(tensor_list).to(device)
            if upsampler.half:
                batch_tensor = batch_tensor.half()

            # Run batched inference directly on model
            with torch.no_grad():
                output_tensor = upsampler.model(batch_tensor)

            # Post-process batch outputs back to numpy images
            output_tensor = output_tensor.float().cpu().clamp_(0, 1).numpy()
            output_tensor = np.transpose(output_tensor, (0, 2, 3, 1)) # CHW to HWC

            for idx, out_img in enumerate(output_tensor):
                out_bgr = (out_img * 255.0).round().astype(np.uint8)
                out_path = os.path.join(output_dir, batch_names[idx])
                # Async save via thread pool
                executor.submit(save_frame, out_path, out_bgr)

        except RuntimeError as error:
            print(f"❌ Error in batch starting at frame {i}: {error}")
            continue

        processed_count = min(i + batch_size, total_frames)
        if processed_count % 10 == 0 or processed_count == total_frames:
            print(f"Progress: [{processed_count}/{total_frames}] frames processed.")

    executor.shutdown(wait=True)
    print("--> Batched CUDA upscaling complete!")

if __name__ == '__main__':
    main()
