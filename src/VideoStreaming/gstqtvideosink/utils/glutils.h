/****************************************************************************
 *
 *   (c) 2009-2018 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


/**
 * @file
 *   @brief QGC Video Item
 *   @author Gus Grubba <mavlink@grubba.com>
 */

#pragma once

#if defined(__mobile__) && !defined(Q_OS_MAC)  && !defined(Q_OS_WIN32)
#include <QOpenGLFunctions>
#define getQOpenGLFunctions() QOpenGLContext::currentContext()->functions()
#define QOpenGLFunctionsDef QOpenGLFunctions
#endif

#ifdef __rasp_pi2__
#include <QOpenGLFunctions_ES2>
#define getQOpenGLFunctions() QOpenGLContext::currentContext()->versionFunctions<QOpenGLFunctions_ES2>()
#define QOpenGLFunctionsDef QOpenGLFunctions_ES2
#endif

#ifndef QOpenGLFunctionsDef
#include <QOpenGLFunctions_2_0>
#define getQOpenGLFunctions() QOpenGLContext::currentContext()->versionFunctions<QOpenGLFunctions_2_0>()
#define QOpenGLFunctionsDef QOpenGLFunctions_2_0
#endif
