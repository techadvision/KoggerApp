#include "navigation_arrow.h"

#include <QtMath>
#include <QtGlobal>
#include <cmath>
#include <draw_utils.h>

NavigationArrow::NavigationArrow(QObject *parent) :
    SceneObject(new NavigationArrowRenderImplementation, parent)
{
    auto* r = RENDER_IMPL(NavigationArrow);
    r->arrowVertices_ = makeArrowVertices();
    r->arrowNormals_ = makeArrowNormals(r->arrowVertices_);
    r->arrowRibs_ = makeArrowRibs();
}

NavigationArrow::NavigationArrowRenderImplementation::NavigationArrowRenderImplementation() :
    position_(QVector3D(0.0f, 0.0f, 0.0f))
{}

NavigationArrow::NavigationArrowRenderImplementation::~NavigationArrowRenderImplementation()
{}

void NavigationArrow::setPositionAndAngle(const QVector3D& position, float degAngle)
{
    auto* r = RENDER_IMPL(NavigationArrow);

    if (std::isfinite(position.x()) &&
        std::isfinite(position.y())) {
        r->position_ = position;
    }

    if (std::isfinite(degAngle)) {
        r->angle_ = degAngle;
    }

    Q_EMIT changed();
}

void NavigationArrow::resetPositionAndAngle()
{
    auto* r = RENDER_IMPL(NavigationArrow);
    r->position_ = QVector3D(0.0f, 0.0f, 0.0f);
    r->angle_ = 0.0f;

    Q_EMIT changed();
}

void NavigationArrow::setSize(int size)
{
    auto* r = RENDER_IMPL(NavigationArrow);
    const int boundedSize = qBound(1, size, 5);

    if (r->size_ == boundedSize) {
        return;
    }

    r->size_ = boundedSize;
    Q_EMIT changed();
}

QVector<QVector3D> NavigationArrow::makeArrowVertices() const
{
    // PULSE TRIAL: replaced the tall pointy 3D arrowhead (with raised apex / inner
    // triangle) with a flat location.svg-style navigation cursor. Forward = +Y
    // (heading rotation is applied via the model matrix, so +Y at angle 0 is correct).
    // T = bow/tip, L/R = stern corners, N = concave stern notch.
    QVector<QVector3D> verts;
    verts.reserve(static_cast<size_t>(2) * static_cast<size_t>(3));

    QVector3D T(  0.0f,  4.0f, 0.0f ); // bow / tip
    QVector3D L( -2.6f, -3.0f, 0.0f ); // port stern corner
    QVector3D R(  2.6f, -3.0f, 0.0f ); // starboard stern corner
    QVector3D N(  0.0f, -1.4f, 0.0f ); // concave stern notch

    // Winding chosen so both faces' normals point +Z (up).
    verts << T << L << N
          << T << N << R;

    return verts;
}

QVector<QVector3D> NavigationArrow::makeArrowNormals(const QVector<QVector3D>& tris) const
{
    QVector<QVector3D> normals;
    normals.reserve(tris.size());

    for (int i = 0; i + 2 < tris.size(); i += 3) {
        const QVector3D& a = tris[i];
        const QVector3D& b = tris[i + 1];
        const QVector3D& c = tris[i + 2];
        QVector3D n = QVector3D::crossProduct(b - a, c - a);
        const float len = n.length();
        if (len < 1e-6f) {
            n = QVector3D(0.0f, 0.0f, 1.0f);
        } else {
            n /= len;
        }
        normals << n << n << n;
    }

    return normals;
}

QVector<QVector3D> NavigationArrow::makeArrowRibs() const
{
    // PULSE TRIAL: dark-red outline tracing the navigation-cursor perimeter
    // (matches makeArrowVertices). Slightly raised in Z to avoid z-fighting with the fill.
    QVector<QVector3D> ribs;
    ribs.reserve(static_cast<size_t>(4) * static_cast<size_t>(2));

    QVector3D T(  0.0f,  4.0f, 0.02f ); // bow / tip
    QVector3D L( -2.6f, -3.0f, 0.02f ); // port stern corner
    QVector3D R(  2.6f, -3.0f, 0.02f ); // starboard stern corner
    QVector3D N(  0.0f, -1.4f, 0.02f ); // concave stern notch

    ribs << T << L
         << L << N
         << N << R
         << R << T;

    return ribs;
}

void NavigationArrow::NavigationArrowRenderImplementation::render(QOpenGLFunctions *ctx,
                                                                  const QMatrix4x4 &mvp,
                                                                  const QMap<QString, std::shared_ptr<QOpenGLShaderProgram> > &shaderProgramMap) const
{
    if (!m_isVisible) {
        return;
    }

    auto litShaderProgram = shaderProgramMap.value("directional_lit", nullptr);
    auto lineShaderProgram = shaderProgramMap.value("static", nullptr);
    if (!shadowEnabled_) {
        litShaderProgram.reset();
    }

    if ((qFuzzyIsNull(angle_) && position_.isNull()) || (!litShaderProgram && !lineShaderProgram)) {
        return;
    }

    EffectiveShadowParams shadow;
    QVector<QVector3D> rotatedNormals;
    if (litShaderProgram) {
        shadow = effectiveShadowParams();
        rotatedNormals = arrowNormals_;
        if (!qFuzzyIsNull(angle_)) {
            QMatrix4x4 normalTransform;
            normalTransform.setToIdentity();
            normalTransform.rotate(angle_, 0.0f, 0.0f, 1.0f);
            for (QVector3D& n : rotatedNormals) {
                n = normalTransform.mapVector(n);
                if (n.lengthSquared() > 1e-12f) {
                    n.normalize();
                } else {
                    n = QVector3D(0.0f, 0.0f, 1.0f);
                }
            }
        }
    }

    if (litShaderProgram && litShaderProgram->bind()) {
        const int posLoc = litShaderProgram->attributeLocation("position");
        const int normalLoc = litShaderProgram->attributeLocation("normal");
        const int matrixLoc = litShaderProgram->uniformLocation("matrix");
        const int colorLoc = litShaderProgram->uniformLocation("color");
        const int lightDirLoc = litShaderProgram->uniformLocation("lightDir");
        const int ambientLoc = litShaderProgram->uniformLocation("ambient");
        const int intensityLoc = litShaderProgram->uniformLocation("intensity");
        const int highlightLoc = litShaderProgram->uniformLocation("highlightIntensity");

        litShaderProgram->setUniformValue(matrixLoc, mvp);
        litShaderProgram->setUniformValue(colorLoc, DrawUtils::colorToVector4d(QColor(0, 128, 0)) /* PULSE TRIAL: boat body green (matches the toggle/position-available green) */);
        if (lightDirLoc >= 0) {
            litShaderProgram->setUniformValue(lightDirLoc, shadow.lightDir);
        }
        if (ambientLoc >= 0) {
            litShaderProgram->setUniformValue(ambientLoc, shadow.ambient);
        }
        if (intensityLoc >= 0) {
            litShaderProgram->setUniformValue(intensityLoc, shadow.intensity);
        }
        if (highlightLoc >= 0) {
            litShaderProgram->setUniformValue(highlightLoc, shadow.highlightIntensity);
        }

        if (posLoc >= 0) {
            litShaderProgram->enableAttributeArray(posLoc);
            litShaderProgram->setAttributeArray(posLoc, arrowVertices_.constData());
            if (normalLoc >= 0) {
                litShaderProgram->enableAttributeArray(normalLoc);
                litShaderProgram->setAttributeArray(normalLoc, rotatedNormals.constData());
            }
            ctx->glDrawArrays(GL_TRIANGLES, 0, arrowVertices_.size());
            if (normalLoc >= 0) {
                litShaderProgram->disableAttributeArray(normalLoc);
            }
            litShaderProgram->disableAttributeArray(posLoc);
        }
        litShaderProgram->release();
    } else if (lineShaderProgram && lineShaderProgram->bind()) {
        const int posLoc = lineShaderProgram->attributeLocation("position");
        const int colorLoc = lineShaderProgram->uniformLocation("color");
        const int matrixLoc = lineShaderProgram->uniformLocation("matrix");

        lineShaderProgram->setUniformValue(matrixLoc, mvp);
        lineShaderProgram->setUniformValue(colorLoc, DrawUtils::colorToVector4d(QColor(0, 128, 0)) /* PULSE TRIAL: boat body green (matches the toggle/position-available green) */);
        lineShaderProgram->enableAttributeArray(posLoc);
        lineShaderProgram->setAttributeArray(posLoc, arrowVertices_.constData());
        ctx->glDrawArrays(GL_TRIANGLES, 0, arrowVertices_.size());
        lineShaderProgram->disableAttributeArray(posLoc);
        lineShaderProgram->release();
    }

    if (lineShaderProgram && lineShaderProgram->bind()) {
        const int posLoc = lineShaderProgram->attributeLocation("position");
        const int colorLoc = lineShaderProgram->uniformLocation("color");
        const int matrixLoc = lineShaderProgram->uniformLocation("matrix");

        lineShaderProgram->setUniformValue(matrixLoc, mvp);
        lineShaderProgram->setUniformValue(colorLoc, DrawUtils::colorToVector4d(QColor(27, 94, 32))); /* PULSE TRIAL: dark-green outline (#1B5E20) to match the boat body green */
        lineShaderProgram->enableAttributeArray(posLoc);
        lineShaderProgram->setAttributeArray(posLoc, arrowRibs_.constData());

        ctx->glLineWidth(2.0f);
        ctx->glDrawArrays(GL_LINES, 0, arrowRibs_.size());
        ctx->glLineWidth(1.0f);

        lineShaderProgram->disableAttributeArray(posLoc);
        lineShaderProgram->release();
    }
}

QVector3D NavigationArrow::NavigationArrowRenderImplementation::getPosition() const
{
    return position_;
}

float NavigationArrow::NavigationArrowRenderImplementation::getAngle() const
{
    return angle_;
}

int NavigationArrow::NavigationArrowRenderImplementation::getSize() const
{
    return size_;
}
