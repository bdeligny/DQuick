module dquick.renderer3D.openGL.renderer;

import dquick.renderer3D.iRenderer;
import dquick.renderer3D.openGL.util;
import dquick.maths.matrix4x4;
import dquick.maths.vector2s32;
import dquick.utils.resourceManager;

import derelict.opengl3.gl;

import std.math;
import std.stdio;

shared static this()
{
	writeln("dquick.renderer3D.openGL.renderer : shared static this()");
	Renderer.resourceManager = new ResourceManager();
	Renderer.resourceManager.maximumWeight(128 * 1000 * 1024);
}

shared static ~this()
{
	writeln("dquick.renderer3D.openGL.renderer : shared static ~this()");
	destroy(Renderer.resourceManager);
	Renderer.resourceManager = null;
}

import dquick.buildSettings;

static if (renderer == RendererMode.OpenGL)
//struct Renderer
final class Renderer : IRenderer
{
	static ResourceManager	resourceManager;	// TODO check the release of resource when it's destroy (need to be destroy before the context) also check it for images

	static void	initialize()										// All Setup For OpenGL Goes Here
	{
		if (mInitialized)
			return;

//		checkgl!glShadeModel(GL_SMOOTH);							// Enable Smooth Shading (deprecated)
		checkgl!glClearColor(1.0f, 1.0f, 1.0f, 1.0f);				// Black Background
		checkgl!glClearDepth(1.0f);									// Depth Buffer Setup
//		checkgl!glEnable(GL_DEPTH_TEST);							// Enables Depth Testing
//		checkgl!glDepthFunc(GL_LEQUAL);								// The Type Of Depth Testing To Do
		checkgl!glDisable(GL_DEPTH_TEST);
		checkgl!glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);	// Really Nice Perspective Calculations
		checkgl!glDisable(GL_CULL_FACE);

		checkgl!glEnable(GL_BLEND);
		checkgl!glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

//		checkgl!glCullFace(GL_FRONT_AND_BACK);

		checkgl!glDisable(GL_TEXTURE_2D);

		checkgl!glPixelStorei(GL_UNPACK_SWAP_BYTES, GL_FALSE);
		checkgl!glPixelStorei(GL_UNPACK_LSB_FIRST, GL_FALSE);
		checkgl!glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
		checkgl!glPixelStorei(GL_UNPACK_SKIP_ROWS, 0);
		checkgl!glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
		checkgl!glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

		mInitialized = true;
	}

	static void	startFrame()
	{
		checkgl!glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);	// Clear Screen And Depth Buffer
	}

	static void	setViewportSize(in Vector2s32 size)
	{
		mViewportSize = size;
		glViewport(0, 0, mViewportSize.x, mViewportSize.y);
	}

	static Vector2s32	viewportSize()
	{
		return mViewportSize;
	}

	static void currentMDVMatrix(Matrix4x4 matrix)
	{
		mCurrentMDV = matrix;
	}

	static Matrix4x4 currentMDVMatrix()
	{
		return mCurrentMDV;
	}

	static void currentCamera(Matrix4x4 camera)
	{
		mCurrentCamera = camera;
	}

	static Matrix4x4	currentCamera()
	{
		return mCurrentCamera;
	}

	static void	startScissor(int x, int y, int width, int height)
	{
		glEnable(GL_SCISSOR_TEST);
		glScissor(x, y, width, height);
	}

	static void	endScissor()
	{
		glDisable(GL_SCISSOR_TEST);
	}

private:
	static bool			mInitialized;
	static Matrix4x4	mCurrentMDV;
	static Matrix4x4	mCurrentCamera;
	static Vector2s32	mViewportSize;
}
