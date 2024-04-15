#include "gtom/include/Prerequisites.cuh"
#include "gtom/include/Angles.cuh"
#include "gtom/include/Helper.cuh"
#include "gtom/include/Relion.cuh"

namespace gtom
{
	template<uint ndims, uint TpB> __global__ void Project3DtoNDKernel(cudaTex t_volumeRe, cudaTex t_volumeIm, uint dimvolume, tcomplex* d_proj, uint dimproj, size_t elementsproj, glm::mat3* d_rotations, uint rmax, int rmax2);
	template<uint ndims, uint TpB> __global__ void Project3DtoNDCTFMultKernel(cudaTex t_volumeRe, cudaTex t_volumeIm, tfloat* d_ctf, uint dimvolume, tcomplex* d_proj, uint dimproj, size_t elementsproj, glm::mat3* d_rotations, uint rmax, int rmax2);
	template<uint ndims, uint TpB> __global__ void Project3DArraytoNDKernel(tcomplex* d_volume, uint dimvolume, tcomplex* d_proj, uint dimproj, size_t elementsproj, glm::mat3* d_rotations, uint rmax, int rmax2);


	void d_rlnProject(tcomplex* d_volumeft, int3 dimsvolume, tcomplex* d_proj, int3 dimsproj, tfloat3* h_angles, float supersample, uint batch)
	{
		glm::mat3* h_matrices = (glm::mat3*)malloc(sizeof(glm::mat3) * batch);
		for (int i = 0; i < batch; i++)
			h_matrices[i] = glm::transpose(Matrix3Euler(h_angles[i])) * Matrix3Scale(supersample);
		glm::mat3* d_matrices = (glm::mat3*)CudaMallocFromHostArray(h_matrices, sizeof(glm::mat3) * batch);
		free(h_matrices);

		d_rlnProject(d_volumeft, dimsvolume, d_proj, dimsproj, dimsproj.x / 2, d_matrices, batch);

		cudaFree(d_matrices);
	}

	void d_rlnProject(tcomplex* d_volumeft, int3 dimsvolume, tcomplex* d_proj, int3 dimsproj, uint rmax, glm::mat3* d_matrices, uint batch)
	{
		uint ndimsvolume = DimensionCount(dimsvolume);
		uint ndimsproj = DimensionCount(dimsproj);
		if (ndimsvolume < ndimsproj)
			throw;

		rmax = tmin(rmax, dimsproj.x / 2);

		uint elements = ElementsFFT(dimsproj);
		dim3 grid = dim3(tmin(64, (elements + 127) / 128), batch, 1);

		if (ndimsproj == 2)
			Project3DArraytoNDKernel<2, 128> << <grid, 128 >> > (d_volumeft, dimsvolume.x, d_proj, dimsproj.x, elements, d_matrices, rmax, rmax * rmax);
		else if (ndimsproj == 3)
			Project3DArraytoNDKernel<3, 128> << <grid, 128 >> > (d_volumeft, dimsvolume.x, d_proj, dimsproj.x, elements, d_matrices, rmax, rmax * rmax);
		else
			throw;
	}

	void d_rlnProject(cudaTex t_volumeRe, cudaTex t_volumeIm, int3 dimsvolume, tcomplex* d_proj, int3 dimsproj, tfloat3* h_angles, float supersample, uint batch)
	{
		glm::mat3* h_matrices = (glm::mat3*)malloc(sizeof(glm::mat3) * batch);
		for (int i = 0; i < batch; i++)
			h_matrices[i] = glm::transpose(Matrix3Euler(h_angles[i])) * Matrix3Scale(supersample);
		glm::mat3* d_matrices = (glm::mat3*)CudaMallocFromHostArray(h_matrices, sizeof(glm::mat3) * batch);
		free(h_matrices);

		d_rlnProject(t_volumeRe, t_volumeIm, dimsvolume, d_proj, dimsproj, dimsproj.x / 2, d_matrices, batch);

		cudaFree(d_matrices);
	}

	void d_rlnProject(cudaTex t_volumeRe, cudaTex t_volumeIm, int3 dimsvolume, tcomplex* d_proj, int3 dimsproj, uint rmax, glm::mat3* d_matrices, uint batch)
	{
		uint ndimsvolume = DimensionCount(dimsvolume);
		uint ndimsproj = DimensionCount(dimsproj);
		if (ndimsvolume < ndimsproj)
			throw;

		rmax = tmin(rmax, dimsproj.x / 2);

		/*int d;
		cudaGetDevice(&d);*/
		//cudaDeviceProp prop;
		//cudaGetDeviceProperties(&prop, 0);
		int maxbatch = 24;// prop.multiProcessorCount;

		for (int b = 0; b < batch; b += maxbatch)
		{
			int curbatch = tmin(maxbatch, batch - b);

			uint elements = ElementsFFT(dimsproj);
			dim3 grid = dim3((elements + 1023) / 1024, curbatch, 1);

			if (ndimsproj == 2)
				Project3DtoNDKernel<2, 128> << <grid, 128 >> > (t_volumeRe, t_volumeIm, dimsvolume.x, d_proj + b * elements, dimsproj.x, elements, d_matrices + b, rmax, rmax * rmax);
			else if (ndimsproj == 3)
				Project3DtoNDKernel<3, 128> << <grid, 128 >> > (t_volumeRe, t_volumeIm, dimsvolume.x, d_proj + b * elements, dimsproj.x, elements, d_matrices + b, rmax, rmax * rmax);
			else
				throw;
		}
	}

	void d_rlnProjectCTFMult(cudaTex t_volumeRe, cudaTex t_volumeIm, tfloat* d_ctf, int3 dimsvolume, tcomplex* d_proj, int3 dimsproj, tfloat3* h_angles, float supersample, uint batch)
	{
		glm::mat3* h_matrices = (glm::mat3*)malloc(sizeof(glm::mat3) * batch);
		for (int i = 0; i < batch; i++)
			h_matrices[i] = glm::transpose(Matrix3Euler(h_angles[i])) * Matrix3Scale(supersample);
		glm::mat3* d_matrices = (glm::mat3*)CudaMallocFromHostArray(h_matrices, sizeof(glm::mat3) * batch);
		free(h_matrices);

		d_rlnProjectCTFMult(t_volumeRe, t_volumeIm, d_ctf, dimsvolume, d_proj, dimsproj, dimsproj.x / 2, d_matrices, batch);

		cudaFree(d_matrices);
	}

	void d_rlnProjectCTFMult(cudaTex t_volumeRe, cudaTex t_volumeIm, tfloat* d_ctf, int3 dimsvolume, tcomplex* d_proj, int3 dimsproj, uint rmax, glm::mat3* d_matrices, uint batch)
	{
		uint ndimsvolume = DimensionCount(dimsvolume);
		uint ndimsproj = DimensionCount(dimsproj);
		if (ndimsvolume < ndimsproj)
			throw;

		rmax = tmin(rmax, dimsproj.x / 2);

		/*int d;
		cudaGetDevice(&d);*/
		//cudaDeviceProp prop;
		//cudaGetDeviceProperties(&prop, 0);
		//int maxbatch = 24;// prop.multiProcessorCount;

		//for (int b = 0; b < batch; b += maxbatch)
		{
			//int curbatch = tmin(maxbatch, batch - b);

			uint elements = ElementsFFT(dimsproj);
			dim3 grid = dim3(tmin((elements + 127) / 128, 8192 / batch), batch, 1);

			if (ndimsproj == 2)
				Project3DtoNDCTFMultKernel<2, 128> << <grid, 128 >> > (t_volumeRe, t_volumeIm, d_ctf, dimsvolume.x, d_proj, dimsproj.x, elements, d_matrices, rmax, rmax * rmax);
			else if (ndimsproj == 3)
				Project3DtoNDCTFMultKernel<3, 128> << <grid, 128 >> > (t_volumeRe, t_volumeIm, d_ctf, dimsvolume.x, d_proj, dimsproj.x, elements, d_matrices, rmax, rmax * rmax);
			else
				throw;
		}
	}

	template<uint ndims, uint TpB> __global__ void Project3DArraytoNDKernel(tcomplex* d_volume, uint dimvolume, tcomplex* d_proj, uint dimproj, size_t elementsproj, glm::mat3* d_rotations, uint rmax, int rmax2)
	{
		d_proj += elementsproj * blockIdx.y;

		int x0, x1, y0, y1, z0, z1;
		tcomplex d000, d010, d100, d110, d001, d011, d101, d111, dx00, dx10, dxy0, dx01, dx11, dxy1;

		uint slice = ElementsFFT1(dimproj) * dimproj;
		uint dimft = ElementsFFT1(dimproj);

		glm::mat3 rotation = d_rotations[blockIdx.y];

		for (uint id = blockIdx.x * blockDim.x + threadIdx.x; id < elementsproj; id += gridDim.x * TpB)
		{
			uint idx = id % dimft;
			uint idy = (ndims == 3 ? id % slice : id) / dimft;
			uint idz = ndims == 3 ? id / slice : 0;

			int x = idx;
			int y = idy <= dimproj / 2 ? idy : (int)idy - (int)dimproj;
			int z = idz <= dimproj / 2 ? idz : (int)idz - (int)dimproj;
			int r2 = ndims == 3 ? z * z + y * y + x * x : y * y + x * x;
			if (r2 > rmax2)
			{
				d_proj[id] = make_cuComplex(0, 0);
				continue;
			}

			tcomplex val;
			glm::vec3 pos = glm::vec3(x, y, z);

			pos = rotation * pos;

			// Only asymmetric half is stored
			float is_neg_x = 1.0f;
			if (pos.x < -1e-5f)
			{
				// Get complex conjugated hermitian symmetry pair
				pos.x = abs(pos.x);
				pos.y = -pos.y;
				pos.z = -pos.z;
				is_neg_x = -1.0f;
			}

			// Trilinear interpolation (with physical coords)
			x0 = floor(pos.x + 1e-5f);
			x1 = x0 + 1;
			pos.x -= floor(pos.x + 1e-5f);

			y0 = floor(pos.y);
			y1 = y0 + 1;
			if (y0 < 0)
				y0 += dimvolume;
			if (y1 < 0)
				y1 += dimvolume;
			pos.y -= floor(pos.y);

			z0 = floor(pos.z);
			z1 = z0 + 1;
			if (z0 < 0)
				z0 += dimvolume;
			if (z1 < 0)
				z1 += dimvolume;
			pos.z -= floor(pos.z);

			d000 = d_volume[(z0 * dimvolume + y0) * (dimvolume / 2 + 1) + x0];
			d001 = d_volume[(z0 * dimvolume + y0) * (dimvolume / 2 + 1) + x1];
			d010 = d_volume[(z0 * dimvolume + y1) * (dimvolume / 2 + 1) + x0];
			d011 = d_volume[(z0 * dimvolume + y1) * (dimvolume / 2 + 1) + x1];
			d100 = d_volume[(z1 * dimvolume + y0) * (dimvolume / 2 + 1) + x0];
			d101 = d_volume[(z1 * dimvolume + y0) * (dimvolume / 2 + 1) + x1];
			d110 = d_volume[(z1 * dimvolume + y1) * (dimvolume / 2 + 1) + x0];
			d111 = d_volume[(z1 * dimvolume + y1) * (dimvolume / 2 + 1) + x1];

			dx00 = lerp(d000, d001, pos.x);
			dx01 = lerp(d010, d011, pos.x);
			dx10 = lerp(d100, d101, pos.x);
			dx11 = lerp(d110, d111, pos.x);

			dxy0 = lerp(dx00, dx01, pos.y);
			dxy1 = lerp(dx10, dx11, pos.y);

			val = lerp(dxy0, dxy1, pos.z);

			val.y *= is_neg_x;

			d_proj[id] = val;
		}
	}

	template<uint ndims, uint TpB> __global__ void Project3DtoNDKernel(cudaTex t_volumeRe, cudaTex t_volumeIm, uint dimvolume, tcomplex* d_proj, uint dimproj, size_t elementsproj, glm::mat3* d_rotations, uint rmax, int rmax2)
	{
		d_proj += elementsproj * blockIdx.y;

		int x0, x1, y0, y1, z0, z1;
		tcomplex d000, d010, d100, d110, d001, d011, d101, d111, dx00, dx10, dxy0, dx01, dx11, dxy1;

		uint slice = ElementsFFT1(dimproj) * dimproj;
		uint dimft = ElementsFFT1(dimproj);

		glm::mat3 rotation = d_rotations[blockIdx.y];

		for (uint id = blockIdx.x * blockDim.x + threadIdx.x; id < elementsproj; id += gridDim.x * TpB)
		{
			uint idx = id % dimft;
			uint idy = (ndims == 3 ? id % slice : id) / dimft;
			uint idz = ndims == 3 ? id / slice : 0;

			int x = idx;
			int y = idy <= dimproj / 2 ? idy : (int)idy - (int)dimproj;
			int z = idz <= dimproj / 2 ? idz : (int)idz - (int)dimproj;
			int r2 = ndims == 3 ? z * z + y * y + x * x : y * y + x * x;
			if (r2 > rmax2)
			{
				d_proj[id] = make_cuComplex(0, 0);
				continue;
			}

			tcomplex val;
			glm::vec3 pos = glm::vec3(x, y, z);

			pos = rotation * pos;

			// Only asymmetric half is stored
			float is_neg_x = 1.0f;
			if (pos.x < -1e-5f)
			{
				// Get complex conjugated hermitian symmetry pair
				pos.x = abs(pos.x);
				pos.y = -pos.y;
				pos.z = -pos.z;
				is_neg_x = -1.0f;
			}

			// Trilinear interpolation (with physical coords)
			x0 = floor(pos.x + 1e-5f);
			pos.x -= x0;
			x0 += 0.5f;
			x1 = x0 + 1.0f;

			y0 = floor(pos.y);
			pos.y -= y0;
			y1 = y0 + 1;
			if (y0 < 0)
				y0 += dimvolume;
			y0 += 0.5f;
			if (y1 < 0)
				y1 += dimvolume;
			y1 += 0.5f;

			z0 = floor(pos.z);
			pos.z -= z0;
			z1 = z0 + 1;
			if (z0 < 0)
				z0 += dimvolume;
			z0 += 0.5f;
			if (z1 < 0)
				z1 += dimvolume;
			z1 += 0.5f;

			d000 = make_cuComplex(tex3D<tfloat>(t_volumeRe, x0, y0, z0), tex3D<tfloat>(t_volumeIm, x0, y0, z0));
			d001 = make_cuComplex(tex3D<tfloat>(t_volumeRe, x1, y0, z0), tex3D<tfloat>(t_volumeIm, x1, y0, z0));
			d010 = make_cuComplex(tex3D<tfloat>(t_volumeRe, x0, y1, z0), tex3D<tfloat>(t_volumeIm, x0, y1, z0));
			d011 = make_cuComplex(tex3D<tfloat>(t_volumeRe, x1, y1, z0), tex3D<tfloat>(t_volumeIm, x1, y1, z0));
			d100 = make_cuComplex(tex3D<tfloat>(t_volumeRe, x0, y0, z1), tex3D<tfloat>(t_volumeIm, x0, y0, z1));
			d101 = make_cuComplex(tex3D<tfloat>(t_volumeRe, x1, y0, z1), tex3D<tfloat>(t_volumeIm, x1, y0, z1));
			d110 = make_cuComplex(tex3D<tfloat>(t_volumeRe, x0, y1, z1), tex3D<tfloat>(t_volumeIm, x0, y1, z1));
			d111 = make_cuComplex(tex3D<tfloat>(t_volumeRe, x1, y1, z1), tex3D<tfloat>(t_volumeIm, x1, y1, z1));

			dx00 = lerp(d000, d001, pos.x);
			dx01 = lerp(d010, d011, pos.x);
			dx10 = lerp(d100, d101, pos.x);
			dx11 = lerp(d110, d111, pos.x);

			dxy0 = lerp(dx00, dx01, pos.y);
			dxy1 = lerp(dx10, dx11, pos.y);

			val = lerp(dxy0, dxy1, pos.z);

			val.y *= is_neg_x;

			d_proj[id] = val;
		}
	}

	template<uint ndims, uint TpB> __global__ void Project3DtoNDCTFMultKernel(cudaTex t_volumeRe, cudaTex t_volumeIm, tfloat* d_ctf, uint dimvolume, tcomplex* d_proj, uint dimproj, size_t elementsproj, glm::mat3* d_rotations, uint rmax, int rmax2)
	{
		d_proj += elementsproj * blockIdx.y;

		int x0, x1, y0, y1, z0, z1;
		tcomplex d000, d010, d100, d110, d001, d011, d101, d111, dx00, dx10, dxy0, dx01, dx11, dxy1;

		uint slice = ElementsFFT1(dimproj) * dimproj;
		uint dimft = ElementsFFT1(dimproj);

		glm::mat3 rotation = d_rotations[blockIdx.y];

		for (uint id = blockIdx.x * blockDim.x + threadIdx.x; id < elementsproj; id += gridDim.x * TpB)
		{
			tfloat ctf = d_ctf[id];

			if (abs(ctf) < 1e-2f)
			{
				d_proj[id] = make_cuComplex(0, 0);
				continue;
			}

			uint idx = id % dimft;
			uint idy = (ndims == 3 ? id % slice : id) / dimft;
			uint idz = ndims == 3 ? id / slice : 0;

			int x = idx;
			int y = idy <= dimproj / 2 ? idy : (int)idy - (int)dimproj;
			int z = idz <= dimproj / 2 ? idz : (int)idz - (int)dimproj;
			int r2 = ndims == 3 ? z * z + y * y + x * x : y * y + x * x;
			if (r2 > rmax2)
			{
				d_proj[id] = make_cuComplex(0, 0);
				continue;
			}

			tcomplex val;
			glm::vec3 pos = glm::vec3(x, y, z);

			pos = rotation * pos;

			// Only asymmetric half is stored
			float is_neg_x = 1.0f;
			if (pos.x < -1e-5f)
			{
				// Get complex conjugated hermitian symmetry pair
				pos.x = abs(pos.x);
				pos.y = -pos.y;
				pos.z = -pos.z;
				is_neg_x = -1.0f;
			}

			// Trilinear interpolation (with physical coords)
			x0 = floor(pos.x + 1e-5f);
			pos.x -= x0;
			x0 += 0.5f;
			x1 = x0 + 1.0f;

			y0 = floor(pos.y);
			pos.y -= y0;
			y1 = y0 + 1;
			if (y0 < 0)
				y0 += dimvolume;
			y0 += 0.5f;
			if (y1 < 0)
				y1 += dimvolume;
			y1 += 0.5f;

			z0 = floor(pos.z);
			pos.z -= z0;
			z1 = z0 + 1;
			if (z0 < 0)
				z0 += dimvolume;
			z0 += 0.5f;
			if (z1 < 0)
				z1 += dimvolume;
			z1 += 0.5f;

			d000 = make_cuComplex(tex3D<tfloat>(t_volumeRe, x0, y0, z0), tex3D<tfloat>(t_volumeIm, x0, y0, z0));
			d001 = make_cuComplex(tex3D<tfloat>(t_volumeRe, x1, y0, z0), tex3D<tfloat>(t_volumeIm, x1, y0, z0));
			d010 = make_cuComplex(tex3D<tfloat>(t_volumeRe, x0, y1, z0), tex3D<tfloat>(t_volumeIm, x0, y1, z0));
			d011 = make_cuComplex(tex3D<tfloat>(t_volumeRe, x1, y1, z0), tex3D<tfloat>(t_volumeIm, x1, y1, z0));
			d100 = make_cuComplex(tex3D<tfloat>(t_volumeRe, x0, y0, z1), tex3D<tfloat>(t_volumeIm, x0, y0, z1));
			d101 = make_cuComplex(tex3D<tfloat>(t_volumeRe, x1, y0, z1), tex3D<tfloat>(t_volumeIm, x1, y0, z1));
			d110 = make_cuComplex(tex3D<tfloat>(t_volumeRe, x0, y1, z1), tex3D<tfloat>(t_volumeIm, x0, y1, z1));
			d111 = make_cuComplex(tex3D<tfloat>(t_volumeRe, x1, y1, z1), tex3D<tfloat>(t_volumeIm, x1, y1, z1));

			dx00 = lerp(d000, d001, pos.x);
			dx01 = lerp(d010, d011, pos.x);
			dx10 = lerp(d100, d101, pos.x);
			dx11 = lerp(d110, d111, pos.x);

			dxy0 = lerp(dx00, dx01, pos.y);
			dxy1 = lerp(dx10, dx11, pos.y);

			val = lerp(dxy0, dxy1, pos.z);

			val.y *= is_neg_x;

			d_proj[id] = val * ctf;
		}
	}
}
