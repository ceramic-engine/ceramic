using System.Runtime.CompilerServices;
using Unity.Burst;

namespace Ceramic.Simd
{
    /// <summary>
    /// Batched vertex emission kernels used by the ceramic Draw backend
    /// when the `ceramic_simd` define is enabled (which is the default).
    ///
    /// The public entry points take managed arrays, pin them with `fixed`
    /// and forward to `[BurstCompile]` kernels operating on raw pointers.
    /// Those kernels are invoked through Burst "direct call": when Burst
    /// is available the call runs the Burst-compiled native version, and
    /// on platforms where Burst is not supported (e.g. WebGL) the same
    /// body runs as plain managed code — still faster than per-scalar
    /// emission because the per-call overhead is paid once per run
    /// instead of once per value.
    ///
    /// This assembly is the only ceramic-related code that needs
    /// `allowUnsafeCode`; it is confined here (see Ceramic.Simd.asmdef)
    /// so the generated game code and user code stay safe-only.
    ///
    /// The vertex layout matches the interleaved buffer of the Draw
    /// backend: [x, y, z, (textureSlot), r, g, b, a, u, v, (custom
    /// float attributes...)], `vertexSize` floats per vertex. The
    /// texture slot component is only present when the current shader
    /// batches multiple textures (`writeSlot != 0`), which shifts the
    /// color/uv/attribute offsets by one.
    ///
    /// Kernels compute in 32-bit floats (like their native and wasm
    /// counterparts on the other ceramic backends): compared to the
    /// scalar path, which computes in doubles before storing to floats,
    /// the difference is bounded by the usual f32 rounding epsilon.
    /// </summary>
    [BurstCompile(CompileSynchronously = true)]
    public static unsafe class Kernels
    {

        // ---- Mesh part ----
        //
        // Emits a run of indexed mesh vertices: sequential u16 indices,
        // positions gathered through the index array and transformed by
        // the affine matrix, colors resolved according to `colorMode`,
        // scaled uvs, and zero-padded custom float attributes.
        //
        // colorMode: 0 = single color (r, g, b, a args)
        //            1 = float colors, sequential (one color per index)
        //            2 = float colors, gathered (one color per vertex)
        //            3 = packed 0xAARRGGBB colors, sequential
        //            4 = packed 0xAARRGGBB colors, gathered

        /// <summary>
        /// Mesh part emission from a 32-bit float vertex source.
        /// `dst`/`idxDst` are the backend vertex/index buffers, written
        /// from `dstOffset` (in floats) / `idxOffset` (in indices).
        /// </summary>
        public static void MeshPartF32(
            float[] dst, int dstOffset, int vertexSize, bool writeSlot,
            ushort[] idxDst, int idxOffset, int idxBase,
            float[] verts, int vertStride,
            int[] indices, int start, int count,
            int colorMode, float[] floatColors, int[] packedColors,
            float r, float g, float b, float a,
            float globalAlpha, bool premultiply, bool zeroAlpha,
            bool hasUvs, double[] uvs, float uvFactorX, float uvFactorY,
            int meshAttrCount, int shaderAttrCount,
            float mA, float mB, float mC, float mD, float mTX, float mTY,
            float z, float slot)
        {
            // `fixed` over a null (or empty) array yields a null pointer,
            // which is fine: kernels never dereference the sources that
            // the flags/color mode exclude.
            fixed (float* pDst = dst)
            fixed (ushort* pIdx = idxDst)
            fixed (float* pVerts = verts)
            fixed (int* pIndices = indices)
            fixed (float* pFloatColors = floatColors)
            fixed (int* pPackedColors = packedColors)
            fixed (double* pUvs = uvs)
            {
                MeshPartF32Impl(
                    pDst + dstOffset, vertexSize, writeSlot ? 1 : 0,
                    pIdx + idxOffset, idxBase,
                    pVerts, vertStride,
                    pIndices, start, count,
                    colorMode, pFloatColors, pPackedColors,
                    r, g, b, a,
                    globalAlpha, premultiply ? 1 : 0, zeroAlpha ? 1 : 0,
                    hasUvs ? 1 : 0, pUvs, uvFactorX, uvFactorY,
                    meshAttrCount, shaderAttrCount,
                    mA, mB, mC, mD, mTX, mTY, z, slot);
            }
        }

        /// <summary>
        /// Mesh part emission from a 64-bit float vertex source
        /// (haxe `Array&lt;Float&gt;` maps to `double[]`).
        /// </summary>
        public static void MeshPartF64(
            float[] dst, int dstOffset, int vertexSize, bool writeSlot,
            ushort[] idxDst, int idxOffset, int idxBase,
            double[] verts, int vertStride,
            int[] indices, int start, int count,
            int colorMode, float[] floatColors, int[] packedColors,
            float r, float g, float b, float a,
            float globalAlpha, bool premultiply, bool zeroAlpha,
            bool hasUvs, double[] uvs, float uvFactorX, float uvFactorY,
            int meshAttrCount, int shaderAttrCount,
            float mA, float mB, float mC, float mD, float mTX, float mTY,
            float z, float slot)
        {
            fixed (float* pDst = dst)
            fixed (ushort* pIdx = idxDst)
            fixed (double* pVerts = verts)
            fixed (int* pIndices = indices)
            fixed (float* pFloatColors = floatColors)
            fixed (int* pPackedColors = packedColors)
            fixed (double* pUvs = uvs)
            {
                MeshPartF64Impl(
                    pDst + dstOffset, vertexSize, writeSlot ? 1 : 0,
                    pIdx + idxOffset, idxBase,
                    pVerts, vertStride,
                    pIndices, start, count,
                    colorMode, pFloatColors, pPackedColors,
                    r, g, b, a,
                    globalAlpha, premultiply ? 1 : 0, zeroAlpha ? 1 : 0,
                    hasUvs ? 1 : 0, pUvs, uvFactorX, uvFactorY,
                    meshAttrCount, shaderAttrCount,
                    mA, mB, mC, mD, mTX, mTY, z, slot);
            }
        }

        // ---- Staged quads ----

        /// <summary>
        /// Emits `quadCount` staged quads in one call. Each record is
        /// `recordSize = 23 + attrCount` floats:
        /// [0]=w [1]=h [2..7]=matrix(a,b,c,d,tx,ty) [8]=z [9]=textureSlot
        /// [10..13]=rgba [14..21]=u0,v0,u1,v1,u2,v2,u3,v3
        /// [22]=flags (bit 0: flipped corner order, bit 1: wireframe)
        /// [23..]=custom float attribute values (attrCount).
        /// Quads are staged on the calling side so that the managed↔Burst
        /// transition cost is paid once per batch of quads instead of
        /// once per quad.
        /// </summary>
        public static void QuadsFlush(
            float[] dst, int dstOffset, int vertexSize, bool writeSlot,
            ushort[] idxDst, int idxOffset, int idxBase,
            float[] records, int recordSize, int attrCount, int quadCount)
        {
            fixed (float* pDst = dst)
            fixed (ushort* pIdx = idxDst)
            fixed (float* pRec = records)
            {
                QuadsFlushImpl(
                    pDst + dstOffset, vertexSize, writeSlot ? 1 : 0,
                    pIdx + idxOffset, idxBase,
                    pRec, recordSize, attrCount, quadCount);
            }
        }

        // ---- Burst kernels ----
        //
        // Pointer + primitive arguments only (bools become ints so the
        // signatures stay blittable for Burst).

        [BurstCompile(CompileSynchronously = true)]
        static void MeshPartF32Impl(
            float* dst, int vertexSize, int writeSlot,
            ushort* idxDst, int idxBase,
            float* verts, int vertStride,
            int* indices, int start, int count,
            int colorMode, float* floatColors, int* packedColors,
            float r, float g, float b, float a,
            float globalAlpha, int premultiply, int zeroAlpha,
            int hasUvs, double* uvs, float uvFactorX, float uvFactorY,
            int meshAttrCount, int shaderAttrCount,
            float mA, float mB, float mC, float mD, float mTX, float mTY,
            float z, float slot)
        {
            int colorOffset = writeSlot != 0 ? 4 : 3;
            int uvOffset = colorOffset + 4;
            int attrOffset = uvOffset + 2;

            float* v = dst;
            for (int n = 0; n < count; n++)
            {
                idxDst[n] = (ushort)(idxBase + n);

                int j = indices[start + n];
                int l = j * vertStride;
                float x = verts[l];
                float y = verts[l + 1];

                v[0] = mTX + mA * x + mC * y;
                v[1] = mTY + mB * x + mD * y;
                v[2] = z;
                if (writeSlot != 0) v[3] = slot;

                WriteColor(v + colorOffset, colorMode, floatColors, packedColors,
                    start + n, j, r, g, b, a, globalAlpha, premultiply, zeroAlpha);

                if (hasUvs != 0)
                {
                    int k = j * 2;
                    v[uvOffset] = (float)uvs[k] * uvFactorX;
                    v[uvOffset + 1] = (float)uvs[k + 1] * uvFactorY;
                }
                else
                {
                    v[uvOffset] = 0f;
                    v[uvOffset + 1] = 0f;
                }

                for (int m = 0; m < shaderAttrCount; m++)
                {
                    v[attrOffset + m] = m < meshAttrCount ? verts[l + 2 + m] : 0f;
                }

                v += vertexSize;
            }
        }

        [BurstCompile(CompileSynchronously = true)]
        static void MeshPartF64Impl(
            float* dst, int vertexSize, int writeSlot,
            ushort* idxDst, int idxBase,
            double* verts, int vertStride,
            int* indices, int start, int count,
            int colorMode, float* floatColors, int* packedColors,
            float r, float g, float b, float a,
            float globalAlpha, int premultiply, int zeroAlpha,
            int hasUvs, double* uvs, float uvFactorX, float uvFactorY,
            int meshAttrCount, int shaderAttrCount,
            float mA, float mB, float mC, float mD, float mTX, float mTY,
            float z, float slot)
        {
            int colorOffset = writeSlot != 0 ? 4 : 3;
            int uvOffset = colorOffset + 4;
            int attrOffset = uvOffset + 2;

            float* v = dst;
            for (int n = 0; n < count; n++)
            {
                idxDst[n] = (ushort)(idxBase + n);

                int j = indices[start + n];
                int l = j * vertStride;
                float x = (float)verts[l];
                float y = (float)verts[l + 1];

                v[0] = mTX + mA * x + mC * y;
                v[1] = mTY + mB * x + mD * y;
                v[2] = z;
                if (writeSlot != 0) v[3] = slot;

                WriteColor(v + colorOffset, colorMode, floatColors, packedColors,
                    start + n, j, r, g, b, a, globalAlpha, premultiply, zeroAlpha);

                if (hasUvs != 0)
                {
                    int k = j * 2;
                    v[uvOffset] = (float)uvs[k] * uvFactorX;
                    v[uvOffset + 1] = (float)uvs[k + 1] * uvFactorY;
                }
                else
                {
                    v[uvOffset] = 0f;
                    v[uvOffset + 1] = 0f;
                }

                for (int m = 0; m < shaderAttrCount; m++)
                {
                    v[attrOffset + m] = m < meshAttrCount ? (float)verts[l + 2 + m] : 0f;
                }

                v += vertexSize;
            }
        }

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        static void WriteColor(
            float* c, int colorMode, float* floatColors, int* packedColors,
            int seqIndex, int vertIndex,
            float r, float g, float b, float a,
            float globalAlpha, int premultiply, int zeroAlpha)
        {
            if (colorMode == 0)
            {
                c[0] = r;
                c[1] = g;
                c[2] = b;
                c[3] = a;
            }
            else if (colorMode <= 2)
            {
                int fc = (colorMode == 1 ? seqIndex : vertIndex) * 4;
                float outA = globalAlpha * floatColors[fc + 3];
                if (premultiply != 0)
                {
                    c[0] = floatColors[fc] * outA;
                    c[1] = floatColors[fc + 1] * outA;
                    c[2] = floatColors[fc + 2] * outA;
                }
                else
                {
                    c[0] = floatColors[fc];
                    c[1] = floatColors[fc + 1];
                    c[2] = floatColors[fc + 2];
                }
                c[3] = zeroAlpha != 0 ? 0f : outA;
            }
            else
            {
                int pc = packedColors[colorMode == 3 ? seqIndex : vertIndex];
                float outA = globalAlpha * (((pc >> 24) & 0xFF) / 255f);
                float cr = ((pc >> 16) & 0xFF) / 255f;
                float cg = ((pc >> 8) & 0xFF) / 255f;
                float cb = (pc & 0xFF) / 255f;
                if (premultiply != 0)
                {
                    c[0] = cr * outA;
                    c[1] = cg * outA;
                    c[2] = cb * outA;
                }
                else
                {
                    c[0] = cr;
                    c[1] = cg;
                    c[2] = cb;
                }
                c[3] = zeroAlpha != 0 ? 0f : outA;
            }
        }

        [BurstCompile(CompileSynchronously = true)]
        static void QuadsFlushImpl(
            float* dst, int vertexSize, int writeSlot,
            ushort* idxDst, int idxBase,
            float* records, int recordSize, int attrCount, int quadCount)
        {
            int colorOffset = writeSlot != 0 ? 4 : 3;
            int uvOffset = colorOffset + 4;
            int attrOffset = uvOffset + 2;

            float* v = dst;
            ushort* idx = idxDst;
            int vbase = idxBase;
            float* rec = records;

            for (int q = 0; q < quadCount; q++)
            {
                float w = rec[0];
                float h = rec[1];
                float mA = rec[2];
                float mB = rec[3];
                float mC = rec[4];
                float mD = rec[5];
                float mTX = rec[6];
                float mTY = rec[7];
                float z = rec[8];
                float slot = rec[9];
                float cr = rec[10];
                float cg = rec[11];
                float cb = rec[12];
                float ca = rec[13];
                int flags = (int)rec[22];

                if ((flags & 2) != 0)
                {
                    // Wireframe: 12 line indices
                    idx[0] = (ushort)vbase;
                    idx[1] = (ushort)(vbase + 1);
                    idx[2] = (ushort)(vbase + 1);
                    idx[3] = (ushort)(vbase + 2);
                    idx[4] = (ushort)(vbase + 2);
                    idx[5] = (ushort)vbase;
                    idx[6] = (ushort)vbase;
                    idx[7] = (ushort)(vbase + 2);
                    idx[8] = (ushort)(vbase + 2);
                    idx[9] = (ushort)(vbase + 3);
                    idx[10] = (ushort)(vbase + 3);
                    idx[11] = (ushort)vbase;
                    idx += 12;
                }
                else
                {
                    idx[0] = (ushort)vbase;
                    idx[1] = (ushort)(vbase + 1);
                    idx[2] = (ushort)(vbase + 2);
                    idx[3] = (ushort)vbase;
                    idx[4] = (ushort)(vbase + 2);
                    idx[5] = (ushort)(vbase + 3);
                    idx += 6;
                }
                vbase += 4;

                // Corners in emission order, same expressions as the
                // scalar path
                float cx0, cy0, cx1, cy1, cx2, cy2, cx3, cy3;
                if ((flags & 1) != 0)
                {
                    // br, bl, tl, tr
                    cx0 = mTX + mA * w + mC * h; cy0 = mTY + mB * w + mD * h;
                    cx1 = mTX + mC * h;          cy1 = mTY + mD * h;
                    cx2 = mTX;                   cy2 = mTY;
                    cx3 = mTX + mA * w;          cy3 = mTY + mB * w;
                }
                else
                {
                    // tl, tr, br, bl
                    cx0 = mTX;                   cy0 = mTY;
                    cx1 = mTX + mA * w;          cy1 = mTY + mB * w;
                    cx2 = mTX + mA * w + mC * h; cy2 = mTY + mB * w + mD * h;
                    cx3 = mTX + mC * h;          cy3 = mTY + mD * h;
                }

                QuadVertex(v, writeSlot, colorOffset, uvOffset, attrOffset, attrCount,
                    rec + 23, cx0, cy0, z, slot, cr, cg, cb, ca, rec[14], rec[15]);
                v += vertexSize;
                QuadVertex(v, writeSlot, colorOffset, uvOffset, attrOffset, attrCount,
                    rec + 23, cx1, cy1, z, slot, cr, cg, cb, ca, rec[16], rec[17]);
                v += vertexSize;
                QuadVertex(v, writeSlot, colorOffset, uvOffset, attrOffset, attrCount,
                    rec + 23, cx2, cy2, z, slot, cr, cg, cb, ca, rec[18], rec[19]);
                v += vertexSize;
                QuadVertex(v, writeSlot, colorOffset, uvOffset, attrOffset, attrCount,
                    rec + 23, cx3, cy3, z, slot, cr, cg, cb, ca, rec[20], rec[21]);
                v += vertexSize;

                rec += recordSize;
            }
        }

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        static void QuadVertex(
            float* v, int writeSlot, int colorOffset, int uvOffset, int attrOffset, int attrCount,
            float* attrs, float x, float y, float z, float slot,
            float r, float g, float b, float a, float u, float uv)
        {
            v[0] = x;
            v[1] = y;
            v[2] = z;
            if (writeSlot != 0) v[3] = slot;
            v[colorOffset] = r;
            v[colorOffset + 1] = g;
            v[colorOffset + 2] = b;
            v[colorOffset + 3] = a;
            v[uvOffset] = u;
            v[uvOffset + 1] = uv;
            for (int m = 0; m < attrCount; m++)
            {
                v[attrOffset + m] = attrs[m];
            }
        }

    }
}
